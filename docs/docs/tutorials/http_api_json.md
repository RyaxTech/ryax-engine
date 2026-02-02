# API Trigger

This tutorial presumes you are acquainted with basic Ryax concepts like workflow, actions, and triggers.
For more information on these concepts see https://docs.ryax.tech/concepts/concepts.html.

The http API trigger allows users to create an API to listen for user data. By design Ryax creates an
API server per project and each workflow can implement one endpoint. To use this feature 
build the [http_api_json](https://gitlab.com/ryax-tech/workflows/default-actions/-/tree/master/triggers/http_api_json) 
trigger from default-actions. If you are already familiar with the process you can skip to Part II.

## Part I - Build HTTP API JSON action

Login onto Ryax UI and click on `Library`

![Library](../_static/http_api/01-add_default_actions_repo.png "Add default-actions repository")

Click on `Add` set name as `default actions` and the url as  
https://gitlab.com/ryax-tech/workflows/default-actions.git and then click on `OK`.

![Add default-actions repository](../_static/http_api/02-add_default_actions_repo_2.png "Add default-actions repository")

Now click on the Repository that appears on the list and click on `Scan now`. Select the branch to 
scan, master is the default, and click `OK`.

![Select default-actions repository](../_static/http_api/03-scan-repository.png "Select default-actions repository")

You will be presented with a list of actions/triggers found. Click on `HTTP API JSON` and click on `Build` on the left.

![Repository screenshot](../_static/http_api/04-build-api-trigger.png "Build HTTP API JSON trigger")


## Part II - Create endpoint workflow

Now that you already have `HTTP API JSON` trigger available you can create
a workflow that implements a simple endpoint. We will create a simple POST that echo the input value as
an output result.

To start click on `Dashboard` and create workflow.

![New workflow](../_static/http_api/05-create_new_workflow.png "Create new workflow")

Select a name and choose as trigger the `HTTP API JSON` trigger built in Part I. 
Edit workflow name to `Echo POST`, fulfill OpenAPI doc parameters summary, tags and description.
Template endpoint is the endpoint rightmost part, to append on the project URL, we used `/echo/post`.
Select the method as `POST`, you can leave `HTTTP success status code` and `Asynchronous Reply Timeout`
to their default values.

![Configure HTTP API JSON trigger](../_static/http_api/06-1-set_endpoint_parameters.png "Create new workflow")

![Configure HTTP API JSON trigger](../_static/http_api/06-2-set_endpoint_parameters.png "Create new workflow")


Now let's add a simple string input. Click on `Add input`. 
Define a name, this will be the name to use on the json 
so make sure it has json valid characters. Choose a help text, select 
`body` as `Origin` and `type` as string. 

![Add input](../_static/http_api/07-add_input.png "Add input")


We are almost ready to deploy and use this workflow as an API. However, we still need to
associate a result value to the workflow. To do that, on the top of the workflow edit page, 
click on `select results`. Then select JSON, set key as any json valid name and select the previously
created input on the combo box.

![Add result](../_static/http_api/08-add_result.png "Add result")

Back on the dashboard the project OpenAPI link is on the top left, below
the project name, click on `Open API` to see the automatically generated
documentation.

![Add result](../_static/http_api/09-check_openapi_doc.png "OpenAPI doc link")

The screenshot below shows the endpoints `/echo/post/` as configured
on `Echo POST` workflow. If you undeploy the workflow and refresh
the documentation page the endpoint will be removed from the OpenAPI doc
page. 

![Add result](../_static/http_api/10-openapi_doc.png "OpenAPI doc")

With the OpenAPI doc you can easily try the `Echo POST` workflow.
Just click `Try it out` and type some relevant info as "string_input" value on the 
json payload, then click on `Execute`. After executing the full workflow
the response payload should contain a json with `echo` result, the value
of `echo` matches the input.

![Add result](../_static/http_api/11_test_echo_post.png "Test echo post")

Finally, you can also check execution details on Ryax as we see below. 

![Add result](../_static/http_api/12_check_associated_execution.png "Execution result")

## Conclusion and further reading

It is possible to configure the return status code to 200 or 201, 202 is reserved
by Ryax to retrieve the result in asynchronous mode. It is also possible
to set error codes by raising RyaxException from any action that follows
`HTTP API JSON` trigger. For more information on that please visit
[the concept documentation page](https://docs.ryax.tech/concepts/concepts.html#api-http-json) on the subject.
