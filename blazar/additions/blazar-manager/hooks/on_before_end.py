#!/usr/bin/env python
"""
Blazar before_end action -- email

Email user about the expiration datetime of the lease.
"""
import argparse
import configparser
import sys
import smtplib
from blazarclient.client import Client as BlazarClient
from datetime import datetime
from dateutil import tz
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from keystoneauth1 import session
from keystoneauth1.identity import v3

import openstack


from jinja2 import Environment

EMAIL_TEMPLATE = """
<style type="text/css">
@font-face {
  font-family: 'Open Sans';
  font-style: normal;
  font-weight: 300;
  src: local('Open Sans Light'), local('OpenSans-Light'), url(http://fonts.gstatic.com/s/opensans/v13/DXI1ORHCpsQm3Vp6mXoaTa-j2U0lmluP9RWlSytm3ho.woff2) format('woff2');
  unicode-range: U+0460-052F, U+20B4, U+2DE0-2DFF, U+A640-A69F;
}
.body {
    width: 90%;
    margin: auto;
    font-family: 'Open Sans', 'Helvetica', sans-serif;
    font-size: 11pt;
    color: #000000;
}
a:link { color: #B40057; text-decoration: underline}
a:visited { color: #542A95; text-decoration: none}
a:hover { color: #B40057; background-color:#C4FFF9; text-decoration: underline }
</style>

<div class="body">
<p>Dear {{ vars['username'] }},</p>
<br>

<p>We're sending this email to inform you that your lease {{ vars['leasename'] }} (ID: {{ vars['leaseid'] }}) under project {{ vars['projectname'] }} on {{ vars['site'] }}
will expire on {{ vars['enddatetime_utc'] }} UTC / {{ vars['enddatetime_ct'] }} Central Time.</p>

{% if vars['servers']  %}
<p>The following instances are provisioned on nodes in this lease, and will be deleted if when the lease ends:</p>
<ul>
  {% for server in vars['servers'] %}
    <li>{{ server.name }} ({{ server.id }})</li>
  {% endfor %}
</ul>
{% endif %}

<p>You can extend your lease using
either the Chameleon <a href='https://chameleoncloud.readthedocs.io/en/latest/technical/reservations.html#extending-a-lease' target='_blank'>web interface</a>
or <a href='https://chameleoncloud.readthedocs.io/en/latest/technical/reservations.html#id5' target='_blank'>command line interface</a>.</p>

{% if vars['site'] == 'KVM@TACC' %}
<p>If you cannot or do not wish to extend your lease, you can save the configuration of instances and relaunch them with
<a href="https://chameleoncloud.readthedocs.io/en/latest/technical/kvm/kvm_gui.html#creating-a-instance-snapshot" target="_blank">image snapshots</a>.
</p>
{% else %}
<p>If you cannot or do not wish to extend your lease, you can save the configuration of instances and relaunch them with updated
images at a later time by using the <a href="https://chameleoncloud.readthedocs.io/en/latest/technical/images.html" target="_blank">cc-snapshot utility</a>
, which is presinstalled on all Chameleon supported images.</p>
{% endif %}

<br>
<p><i>
This is an automatic email, please <b>DO NOT</b> reply!
If you have any question or issue, please submit a ticket on our <a href='https://www.chameleoncloud.org/user/help/' target='_blank'>help desk</a>.
</i></p>

<br><br>
<p>Thanks,</p>
<p>Chameleon Team</p>

</div>
<br><br>
"""


def render_template(**kwargs):
    """ renders a Jinja template into HTML """
    templ = Environment().from_string(EMAIL_TEMPLATE)
    return templ.render(**kwargs)


def send_email(email_host, email_port, email_ssl, email_user, email_password, to, sender, cc=None, bcc=None, subject=None, body=None):
    # convert TO into list if string
    if type(to) is not list:
        to = to.split()

    try:
        email_port = int(email_port)
    except ValueError:
        print(f"Invalid value for smtp port, expected int: {email_port}")
        sys.exit(1)

    try:
        email_ssl = bool(email_ssl)
    except ValueError:
        print(f"Invalid value for smtp ssl, expected bool: {email_ssl}")
        sys.exit(1)

    to_list = [addr for addr in (to + [cc] + [bcc]) if addr is not None]

    msg = MIMEMultipart("alternative")
    msg["From"] = sender
    msg["Subject"] = subject
    msg["To"] = ",".join(to)
    msg["Cc"] = cc
    msg["Bcc"] = bcc
    msg.attach(MIMEText(body, "html"))

    # send email
    if email_ssl:
        server = smtplib.SMTP_SSL(email_host, email_port, timeout=30)
    else:
        server = smtplib.SMTP(email_host, email_port, timeout=30)
    if email_user and email_password:
        server.login(email_user, email_password)
    server.sendmail(sender, to_list, msg.as_string())
    server.quit()


def main(argv):
    parser = argparse.ArgumentParser(
        description="Send notification email to Chameleon user before lease expires."
    )
    parser.add_argument(
        "--to",
        type=str,
        help="Comma separated list of email addresses of recipients",
        required=True,
    )
    parser.add_argument(
        "--sender",
        type=str,
        help="Email address of sender",
        default="noreply@chameleoncloud.org",
    )
    parser.add_argument("--cc", type=str, help="Email address to cc to", default=None)
    parser.add_argument("--bcc", type=str, help="Email address to bcc to", default=None)

    parser.add_argument("--username", type=str, help="User name", required=True)
    parser.add_argument("--project-name", type=str, help="Project name", required=True)
    parser.add_argument("--project-id", type=str, help="Project ID", required=True)
    parser.add_argument("--lease-name", type=str, help="Lease name", required=True)
    parser.add_argument("--lease-id", type=str, help="Lease id", required=True)
    parser.add_argument(
        "--end-datetime", type=str, help="Lease end date and time in UTC", required=True
    )
    parser.add_argument("--site", type=str, help="Chameleon site", required=True)

    args = parser.parse_args(argv[1:])
    enddatetime_in_utc = datetime.strptime(
        args.end_datetime, "%Y-%m-%d %H:%M:%S"
    ).replace(tzinfo=tz.tzutc())
    enddatetime_in_central = enddatetime_in_utc.astimezone(tz.gettz("America/Chicago"))

    blazar_config = configparser.ConfigParser()
    blazar_config.read("/etc/blazar/blazar.conf")
    servers_in_lease = []
    try:
        auth_config = blazar_config['keystone_authtoken']
        auth = v3.Password(
            auth_url=auth_config.get('auth_url'),
            username=auth_config.get('username'),
            password=auth_config.get('password'),
            user_domain_name=auth_config.get('user_domain_name', 'Default'),
            project_name=auth_config.get('project_name'),
            project_domain_name=auth_config.get('project_domain_name', 'Default')
        )
        sess = session.Session(auth=auth)

        bc = BlazarClient("1", service_type="reservation", session=(sess))

        conn = openstack.connection.Connection(session=sess)
        if args.site != 'KVM@TACC':
            hosts_by_id = {}
            for host in bc.host.list():
                hosts_by_id[host["id"]] = host["hypervisor_hostname"]
            hosts_in_lease = set()
            for resource in bc.host.list_allocations():
                for reservation in resource["reservations"]:
                    if args.lease_id == reservation["lease_id"]:
                        hosts_in_lease.add(
                            hosts_by_id[resource["resource_id"]]
                        )

            for server in conn.compute.servers(project_id=args.project_id, all_tenants=True):
                if server.hypervisor_hostname in hosts_in_lease:
                    servers_in_lease.append(server)
        else:
            # For KVM, find servers based on flavor
            lease = bc.lease.get(args.lease_id)
            for reservation in lease["reservations"]:
                if reservation["resource_type"] == "flavor:instance":
                    for server in conn.compute.servers(
                        project_id=args.project_id,
                        all_tenants=True
                    ):
                        server_res_id = server.flavor.extra_specs.get("aggregate_instance_extra_specs:reservation")
                        if server_res_id == reservation["id"]:
                            servers_in_lease.append(server)
    except Exception as e:
        # Ignore errors
        print("Error getting server info")
        print(e)
        pass

    template_vars = {
        "username": args.username,
        "projectname": args.project_name,
        "projectid": args.project_id,
        "leasename": args.lease_name,
        "leaseid": args.lease_id,
        "enddatetime_utc": enddatetime_in_utc.strftime("%Y-%m-%d %H:%M:%S"),
        "enddatetime_ct": enddatetime_in_central.strftime("%Y-%m-%d %H:%M:%S"),
        "site": args.site,
        "servers": servers_in_lease,
    }

    td = enddatetime_in_utc - datetime.now(tz.tzutc())
    subject = "Chameleon lease {} ending in {} hours".format(
        args.lease_name, str(int(td.total_seconds() / 3600))
    )

    html = render_template(vars=template_vars)

    # read email host from blazar.conf
    email_host = "127.0.0.1"
    # smtplib's default is 0, defaults to OS implementation
    email_port = 0
    email_ssl = False
    email_user = None
    email_password = None
    try:
        email_host = blazar_config["physical:host"]["email_relay"]
        # smtplib's default is 0, defaults to OS implementation
        email_port = blazar_config["physical:host"].get("email_port", 0)
        email_ssl = blazar_config["physical:host"].get("email_ssl", False)
        email_user = blazar_config["physical:host"].get("email_user")
        email_password = blazar_config["physical:host"].get("email_password")
    except Exception:
        pass
    send_email(email_host, email_port, email_ssl, email_user, email_password, args.to, args.sender, args.cc, args.bcc, subject, html)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
