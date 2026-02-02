
# Public actions and triggers

Here is the list of actions and triggers builtin Ryax.

The code source of these actions are published in an open source license and can be found [here](https://gitlab.com/ryax-tech/workflows/default-actions).

<style>

nz-card {
background-attachment: scroll;
background-clip: border-box;
background-color: rgb(255, 255, 255);
background-image: none;
background-origin: padding-box;
background-position-x: 0%;
background-position-y: 0%;
background-repeat: repeat;
background-size: auto;
border-bottom-color: rgb(240, 240, 240);
border-bottom-left-radius: 8px;
border-bottom-right-radius: 8px;
border-bottom-style: solid;
border-bottom-width: 0.8px;
border-image-outset: 0;
border-image-repeat: stretch;
border-image-slice: 100%;
border-image-source: none;
border-image-width: 1;
border-left-color: rgb(240, 240, 240);
border-left-style: solid;
border-left-width: 0.8px;
border-right-color: rgb(240, 240, 240);
border-right-style: solid;
border-right-width: 0.8px;
border-top-color: rgb(240, 240, 240);
border-top-left-radius: 8px;
border-top-right-radius: 8px;
border-top-style: solid;
border-top-width: 0.8px;
box-sizing: border-box;
color: rgb(30, 23, 53);
display: block;
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 14px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
line-height: 22px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;
margin-bottom: 32px;
margin-left: 0px;
margin-right: 0px;
margin-top: 0px;
overflow-x: hidden;
overflow-y: hidden;
padding-bottom: 0px;
padding-left: 0px;
padding-right: 0px;
padding-top: 0px;
position: relative;
width: 566px;
}

.ant-card-body {
align-items: center;
box-sizing: border-box;
color: rgb(30, 23, 53);
display: flex;
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 14px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
line-height: 22px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;
padding: 0px;
display: flex;
align-items: center;
}

.ryax-module-icon {
box-sizing: border-box;
color: rgb(30, 23, 53);
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 14px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
line-height: 22px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;
margin-right: 16px;
position: relative;
}

.ryax-module-icon img {
box-sizing: border-box;
min-height: 72px;
vertical-align: middle;
width: 72px;
}

nz-card img::after {
box-shadow: rgb(199, 197, 205) 0px 0px 5px 0px inset;
box-sizing: border-box;
color: rgb(30, 23, 53);
content: "";
display: block;
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 14px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
height: 72px;
line-height: 22px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;
pointer-events: none;
position: absolute;
top: 0px;
width: 72px;
}

.ng-star-inserted {
box-sizing: border-box;
color: rgb(30, 23, 53);
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 14px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
line-height: 22px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;

}


.ryax-card-title {
box-sizing: border-box;
color: rgb(30, 23, 53);
display: inline-block;
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 18px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
font-weight: 700;
line-height: 28.2833px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;
margin-bottom: 0px;
margin-left: 0px;
margin-right: 0px;
margin-top: 0px;
}


.ryax-card-version {
box-sizing: border-box;
color: rgb(165, 162, 174);
display: inline-block;
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 11px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
line-height: 17.2833px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;
margin-left: 16px;
}


.ryax-card-description {
box-sizing: border-box;
color: rgb(91, 104, 114);
font-family: Nunito Sans, Arial, Noto Sans, sans-serif, Apple Color Emoji, Segoe UI Emoji, Segoe UI Symbol, Noto Color Emoji;
font-feature-settings: "tnum", "tnum";
font-size: 13px;
font-variant-alternates: normal;
font-variant-caps: normal;
font-variant-east-asian: normal;
font-variant-ligatures: normal;
font-variant-numeric: tabular-nums;
font-variant-position: normal;
line-height: 20.4333px;
list-style-image: none;
list-style-position: outside;
list-style-type: none;
margin-bottom: 0px;
margin-left: 0px;
margin-right: 0px;
margin-top: 0px;
text-overflow: ellipsis;
word-wrap: break-word;
overflow: hidden;
max-height: 42px;
max-width: 500px;
}

</style>
    
## Triggers

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/web-hosting-static-dir.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Web hosting for static content</p>
            <span class="ryax-card-version">1.4</span>
            <p class="ryax-card-description">Host a set of static file can be use static web site or any directory full of files</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/one-run.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Run once</p>
            <span class="ryax-card-version">1.1</span>
            <p class="ryax-card-description">Launches a single run of the workflow</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/postgw.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">HTTP POST</p>
            <span class="ryax-card-version">1.5</span>
            <p class="ryax-card-description">Triggered on receiving data on an HTTP POST request or through an online integrated form. </p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/crongw.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Cron source</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Trigger a new run with regards to the cron expression provided.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/mqttgw.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">MQTT Source</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Ingest data from an MQTT server. Each message on the given topic will trigger a run.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Trigger workflow From Gitlab merge request</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">This action is triggered when a new merge request is created, an existing merge request was updated/merged/closed or a commit is added in the source branch on Gitlab. Use this url to create an event : https://gitlab.com/file/project/-/hooks. Select Merge requests events and set the url of the action and the secret token from inputs. </p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/emitevery.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Emit Every</p>
            <span class="ryax-card-version">1.2</span>
            <p class="ryax-card-description">Create a new run at a given rate</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Trigger workflow From Gitlab pipeline</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">This action is triggered when A Gitlab pipeline status changes. Use this url to create an event : https://gitlab.com/file/project/-/hooks. Select Pipeline events and set the url of the action and the secret token from inputs. </p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Trigger workflow From Gitlab release</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">This action is triggered when a release is created or updated on Gitlab. Use this url to create an event : https://gitlab.com/file/project/-/hooks. Select Release events and set the url of the action and the secret token from inputs. </p>
        </div>
    </div>
</nz-card>
    
## Actions

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/send-email.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Send e-mail</p>
            <span class="ryax-card-version">1.1</span>
            <p class="ryax-card-description">This action sends email using an SMTP server (doesn't support Gmail host).</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Publish alert on slack channel</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Publish notifications on slack channel with Apprise. Generate Webhook URL from https://my.slack.com/services/new/incoming-webhook/</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/dir-archive.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Archive a directory</p>
            <span class="ryax-card-version">1.1</span>
            <p class="ryax-card-description">Archive a directory into a zip file.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Publish a tweet on twitter</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Publish a tweet message on twitter. Create a twitter app from apps.twiter.com and then generate access token from "generate the Access Tokens" menu</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/floattoinfluxdb.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Push a float into influxdb</p>
            <span class="ryax-card-version">1.1</span>
            <p class="ryax-card-description">Save a float to an influxdb instance.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/print-env.jpg">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Print Environment</p>
            <span class="ryax-card-version">1.1</span>
            <p class="ryax-card-description">Print the environment of the module: all the environements variables and all the files.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/upload-to-bucket.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Upload file to aws</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Upload input file to an AWS Bucket</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Unpack zipfile</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Unpack a zipfile.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">String to Text File</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Write the input string to a text file and output it</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/send-email-attachment.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Send e-mail with attachment file</p>
            <span class="ryax-card-version">1.1</span>
            <p class="ryax-card-description">This action sends email with attachment file using an SMTP server (doesn't support Gmail host).</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/catfile.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Cat content of a file</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Get the content of a file and put in the output of this action, as a string.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/gcp-storage-writer.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Google cloud storage</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Push file and directory to Google Cloud Storage</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/sleep.jpg">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Sleep</p>
            <span class="ryax-card-version">1.2</span>
            <p class="ryax-card-description">Sleep for a given number of seconds</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/cliq-message.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Send a message to cliq</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Publish a message to cliq channel.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/download-from-bucket.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Download an object from AWS S3 Bucket.</p>
            <span class="ryax-card-version">1.1</span>
            <p class="ryax-card-description">Download file using given object key from s3 bucket and matching strategy.</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/default_logo.png">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">Echo inputs into outputs</p>
            <span class="ryax-card-version">1.2</span>
            <p class="ryax-card-description">Echo all inputs into outputs. For testing purpose!</p>
        </div>
    </div>
</nz-card>
    

<nz-card  class="ant-card ant-card-bordered">
    <div class="ant-card-body">
        <div class="ryax-module-icon">
            <img src="/_static/action_logos/sql-query.jpeg">
        </div>
        <div class="ng-star-inserted">
            <p class="ryax-card-title">SQL Query</p>
            <span class="ryax-card-version">1.0</span>
            <p class="ryax-card-description">Make an SQL query and return the result in a file.</p>
        </div>
    </div>
</nz-card>
    

## And more to come…

Here’s a not exhaustive/non-guaranteed list of the public actions & triggers we are currently working on… get in touch with us for updates!
- Streamlit
- Bubble
- Waalaxy
- Hubspot
- Google Sheet



