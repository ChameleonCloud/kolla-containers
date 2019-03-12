#!/usr/bin/env python
'''
Blazar before_end action -- email

Email user about the expiration datetime of the lease.
'''
import argparse
import os
import sys
import smtplib
from datetime import datetime
from dateutil import tz
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

if sys.version_info[0] == 2:
    import ConfigParser as configparser
else:
    import configparser

from jinja2 import Environment, BaseLoader

EMAIL_TEMPLATE = '''
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

<p>You can extend your lease using
either the Chameleon <a href='https://chameleoncloud.readthedocs.io/en/latest/technical/reservations.html#extending-a-lease' target='_blank'>web interface</a>
or <a href='https://chameleoncloud.readthedocs.io/en/latest/technical/reservations.html#id5' target='_blank'>command line interface</a>.</p>

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
'''

def render_template(**kwargs):
    ''' renders a Jinja template into HTML '''
    templ = Environment().from_string(EMAIL_TEMPLATE)
    return templ.render(**kwargs)

def send_email(email_host, to, sender, cc=None, bcc=None, subject=None, body=None):
    # convert TO into list if string
    if type(to) is not list:
        to = to.split()

    to_list = to + [cc] + [bcc]
    to_list = filter(None, to_list) # remove null emails

    msg = MIMEMultipart('alternative')
    msg['From'] = sender
    msg['Subject'] = subject
    msg['To'] = ','.join(to)
    msg['Cc'] = cc
    msg['Bcc'] = bcc
    msg.attach(MIMEText(body, 'html'))

    # send email
    server = smtplib.SMTP(email_host, timeout=30)
    server.sendmail(sender, to_list, msg.as_string())
    server.quit()

def main(argv):
    parser = argparse.ArgumentParser(description='Send notification email to Chameleon user before lease expires.')
    parser.add_argument('--to', type=str, help='Comma separated list of email addresses of recipients', required=True)
    parser.add_argument('--sender', type=str, help='Email address of sender', default='noreply@chameleoncloud.org')
    parser.add_argument('--cc', type=str, help='Email address to cc to', default=None)
    parser.add_argument('--bcc', type=str, help='Email address to bcc to', default=None)

    parser.add_argument('--username', type=str, help='User name', required=True)
    parser.add_argument('--project-name', type=str, help='Project name', required=True)
    parser.add_argument('--lease-name', type=str, help='Lease name', required=True)
    parser.add_argument('--lease-id', type=str, help='Lease id', required=True)
    parser.add_argument('--end-datetime', type=str, help='Lease end date and time in UTC', required=True)
    parser.add_argument('--site', type=str, help='Chameleon site', required=True)

    args = parser.parse_args(argv[1:])
    enddatetime_in_utc = datetime.strptime(args.end_datetime, '%Y-%m-%d %H:%M:%S').replace(tzinfo=tz.gettz('UTC'))
    enddatetime_in_central = enddatetime_in_utc.astimezone(tz.gettz('America/Chicago'))

    template_vars = {
        'username': args.username,
        'projectname': args.project_name,
        'leasename': args.lease_name,
        'leaseid': args.lease_id,
        'enddatetime_utc': enddatetime_in_utc.strftime("%Y-%m-%d %H:%M:%S"),
        'enddatetime_ct': enddatetime_in_central.strftime("%Y-%m-%d %H:%M:%S"),
        'site': args.site
    }

    td = enddatetime_in_utc - datetime.now(tz.gettz('UTC'))
    subject = 'Chameleon lease {} ending in {} hours'.format(args.lease_name, str(int(td.total_seconds() / 3600)))

    html = render_template(vars=template_vars)

    # read email host from blazar.conf
    email_host = '127.0.0.1'
    blazar_config = configparser.ConfigParser()
    try:
        blazar_config.read('/etc/blazar/blazar.conf')
        email_host = blazar_config['physical:host']['email_relay']
    except Exception:
        pass
    send_email(email_host, args.to, args.sender, args.cc, args.bcc, subject, html.encode("utf8"))

if __name__ == '__main__':
    sys.exit(main(sys.argv))
