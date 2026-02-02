# Actions and Triggers


Ryax supports actions in several languages.

- **python3**
- **NodeJS**
- **C#**

Triggers are only supported in **python3**.

Here, we will describe what a Ryax python action is, what it consists of, as well as some technical functionalities made available.

You can find examples of actions and triggers here: [Ryax default actions](https://gitlab.com/ryax-tech/workflows/default-actions).

## General

An action or a trigger requires at least 2 files: the python code in a `.py` file, and the Ryax metadata file: `ryax_metadata.yaml`. If the action has some external dependencies such as Pypi packages, or anything outside the python standard library (ex: `pandas`, `tensorflow`), it needs a standard `requirements.txt` file with those dependencies listed on separate lines in plain text. You can also add a logo to your action, to easily identify it in the webui. This logo must be at most `250x250px`, and be in either `jpg` or `png` format.

### Dependencies

### Python version

The version of python can be specified in the file `ryax_metadata.yaml`, with the field `spec.option.python.version`.
The declaration of the version should follow the pattern `major.minor`, for instance `3.11`.

#### Python dependencies

In a typical python3 program, you might need to install some dependencies for your program to work. The common approach is to have a file `requirements.txt` with a list of all packages needed. Ryax will look at this file in the root of the action to know the external python libraries that are required by your code.
If your code does not have any external dependencies, you can omit this file.

Windows users must be careful because windows sometimes adds a .txt resulting in a `requirements.txt.txt`.

A `requirements.txt` file consists of a list of python dependencies, one per line. **It is highly recommended to add version constraints to be sure that you always have the same version when your action is built**:
```
pandas==2.1.4
tensorflow==1.3.0
pillow==7.0.0
```
You can look for all available python dependencies on [Pypi](https://pypi.org/).

#### Binary dependencies

If you have non-python dependencies (called "binary dependencies"), you can specify them in the `dependencies` field of the `ryax_metadata.yaml` file. It is possible that some actions require a binary dependency to work, like `opencv` of `git`. We use the Nix package manager to install these dependencies. You can look for all supported dependencies, and their version, in the [nixpkgs search tool](https://search.nixos.org/packages).

For example, to add `git` and `opencv` to your action, just add:
```yaml
spec:
  dependencies:
    - git
    - opencv
```

It is also possible to choose the version of nixpkgs to use by specifying the field `spec.options.nixpkgs.version` in the `ryax_metadata.yaml` file.
The value can be either a branch name, a tag or a commit sha of the repository [nixpkgs](https://github.com/NixOS/nixpkgs/).
For instance, to use the unstable branch of nixgpks:

```yaml
spec:
  options:
    nixpkgs:
      version: nixos-unstable
```

``` ..note::
    The website `https://lazama.co.uk/nix-versions <https://lazamar.co.uk/nix-versions/>`_ helps you find the nixpkgs version that contains the version of a package.
```

#### Custom dependencies with Nix Overlays

If you need customize some packages or to add new ones that are not available in the Nixpkgs repository, Ryax allows you to create Nix Overlays.
To do so, create an `overlays.nix` file in your Action directory. It will be loaded automatically at build time and added to your action environment.
To make the custom packages available in your Action environment you have to add them in the binary dependency list of the `ryax_metadata.yaml` file.

For example, if you want `opencv` but with `Tesseract` support enabled to your action, create an `overlays.nix` file:
```nix
[
  (self: super: {
    opencvWithTesseract = self.opencv.override { enableTesseract = true; };
  })
]
```
And in your `ryax_metadata.yaml`:
```yaml
spec:
  dependencies:
    - opencvWithTesseract
```

### Metadata file

To describe your action, you need a `ryax_metadata.yaml` file that contains a high-level description of your action and the inputs/outputs. The file `ryax_metadata.yaml` follows the [YAML standard](https://en.wikipedia.org/wiki/YAML).

Here is an example of `ryax_metadata.yaml` file:

```yaml
apiVersion: "ryax.tech/v2.0"
kind: Processor
spec:
  id: tfdetection
  human_name: Tag objects
  description: "Tag detected objects on images using Tensorflow"
  type: python3
  version: "1.0"
  logo: mylogo.png
  resources:
    cpu: 2
    memory: 4G
  dependencies:
  - opencv
  inputs:
  - help: Model used to tag the images
    human_name: Model name
    name: model
    type: enum
    enum_values:
     - ssdlite_mobilenet_v2_coco_2018_05_09
     - mask_rcnn_inception_v2_coco_2018_01_28
    default_value: ssdlite_mobilenet_v2_coco_2018_05_09
  - help: An image to be tagged; in any format accepted by OpenCV
    human_name: Image
    name: image
    type: file
  outputs:
  - help: Path of the tagged image
    human_name: Tagged image
    name: tagged_image
    type: file
```

Reference definitions of each field:

- `kind`: to tell the *kind* of the action: accepted values are **Trigger, Processor, Publisher**
- `id`:  unique name of the action (must contains only alphanumeric characters and dash)
- `version`: unique version of the action (must contains only alphanumeric characters and dash)
- `human_name`: a short name, readable by a human
- `description`: a description of the action
- `type`: the programming language. Supported values are: `python3`, `python3-cuda`, `nodejs`, `csharp-dotnet6`
- `logo` (optional): a relative path to a logo file
- `resources`: to set the amount of resources that your Action will ask by default
  - `cpu` (float): the number of cpu core (can be a fraction of cpu, i.e `O.5`)
  - `memory` (string | int): the amount of memory in bytes. Allowed units are (K,M,G,T)
  - `time` (string | int): the maximum time in seconds that should be allocated to the action execution before it is cancelled. Allowed units are (s,m,h,d)
  - `gpu` (int): the number of GPU
- `dependencies` (optional list(string)): list of packages to add to your Action's environment (See above for more details)
- `categories` (optional list(string)): list of labels to be added to your action. This is only used as metadata (e.g. filtering in the dashboard)
- `dynamic_outputs` (boolean): *optional, and only for advanced usage*. (default to false). Only triggers may have dynamic outputs. This is useful in some cases such as when using an online form which can be filled out, to trigger workflows. This feature allows for the reuse of all the code for that trigger, while also allowing users to re-define the fields on that form in different workflow
- `inputs`: list of inputs values injected in the action context:
  - `name`: the name of your variable in your code. Is must not contain spaces or special characters except for `_`. The input dict of you handler contains an entry with this name
  - `human_name`: a human readable name
  - `help`: describes your variable usage
  - `type`: the action IO types. See the following table
  - `optional`: whether your IO is optional or not. If true it will accept a `None` value
  - `enum_values` (Only for enum type): a list of values accepted by your enum
  - `default_value` (Optional and only for inputs): give a default value for this input
- `outputs`: list of outputs returned by the action. Uses the same format as `inputs`

You can find a lot of examples from our public [Ryax Actions repositories](https://gitlab.com/ryax-tech/workflows).

### Ryax Types

Ryax Actions inputs and outputs are typed. Here is the list of available types:

| Type | Description |
|-------------|-----------------------------------------------------------|
| string | String of characters |
| longstring | Use for long text (Larger UI inputs) |
| password | String hidden on the UI |
| integer | 64-bit integer |
| float | floating-point number |
| boolean | True of False |
| enum | Enumeration with a list of possible values |
| file | File (imported and exported by Ryax) |
| directory | Directory containing a set of files (imported and exported by Ryax) |

!!! tip
    If you need more complexe type, serialize it to a file!

### The Code

Ryax knows how to call your code by importing a python code and starting a specific function in it.

Depending on the `kind` of the action, we use 2 different filenames:

- `ryax_run.py` for triggers
- `ryax_handler.py` for all other actions

When creating a action, Ryax will copy all the files that are in the action directory. Thus, if you split your code in multiple files and use some resource files, they will be copied into the action.


## Actions

The `ryax_handler.py` file should contain a `handle` method that takes a `dict` as first parameter and returns a `dict` or a `list` of `dict`.

```python
def handle(request: dict)->dict:
    a = request["an_integer_input"] # define in the `name` field
    a = a + 42
    return {
        "output1": "value",
        "output2": a,
    }
```

By looking at this code, we can guess that this action has at least an input called `an_integer_input` (an integer), and has 2 outputs: `output1` and `output2`. Ryax should know about these by describing them in the `ryax_metadata.yaml` file.

The `handle` function must return a `dict`, it should contain an entry for all outputs of the action, with a valid value, as defined and typed in the `ryax_metadata.yaml` file.

### User defined errors

A common user-case in Ryax is to set up an API endpoint using the builtin `HTTP API JSON` trigger. Likely you will want to configure your return codes alongside this. To do so, in your `handler.py` file you may define an exception with the following signature:

```python
from dataclasses import dataclass


@dataclass
class RyaxException(Exception):
    message: str
    code: int
```

And then in your handle code you may invoke that Exception as follows:

```python3
def handle(request: dict)->dict:
    raise RyaxException(message="My error message", code = 404)

```

Raising the exception as done above will be caught by Ryax, and cancel the current run of your workflow. If this occurred in the context of an API endpoint, the endpoint will return the status code you have set, along with the error message.


## Triggers

`ryax_run.py` is the file to write your python code for a trigger. This script must contain a `run` function that takes 2 parameters: a `dict` containing the inputs and an instance of the `RyaxSourceProtocol` class.

```python3
import asyncio
from ryax_wrapper import RyaxSourceProtocol  #optional import

async def run(service: RyaxSourceProtocol, input_values: dict) -> None:
    while True:
        text = source.inputs_values["input1"]
        source.create_run({"output1": "hello "+text})
        await asyncio.sleep(1)
```

In this particular case, we are creating an execution every second. We can guess that this action has 1 input called `input1` and 1 output called `output1`. Ryax should know about these by describing them in the `ryax_metadata.yaml` file.

Here is the interface of `RyaxSourceProtocol`:

```python3
class RyaxRunStatus(Enum):
    DONE = 1
    ERROR = 2


class RyaxSourceProtocol(metaclass=abc.ABCMeta):
    async def create_run_error(self) -> None:
        await self.create_run({}, status=RyaxRunStatus.ERROR)

    @abc.abstractmethod
    async def create_run(
        self,
        data: dict,
        running_time: float = 0.001,
        status: RyaxRunStatus = RyaxRunStatus.DONE,
    ) -> None:
        ...

    def get_output_definitions(self) -> Dict[str, Any]:
        ...
```



## Migrating from v1 to v2.0

*Most of the specifications stay the same, except the following.*

**`ryax_metadata.yaml` changes:**

- `apiVersion: "ryax.tech/v2.0"`
- `kind` changes: `Gateways` is now `Source`, `Functions` is now `Processor`, `Publishers` is now `Publisher`
- `spec.detail` becomes `spec.description`

The `requirements.txt` is now completly standard.

`handler.py` has to be renamed `ryax_handler.py`.

`run.py` has to be renamed `ryax_run.py`.
Also, the content has to be changed, we do not use a class anymore.
You have to use a `run` function has explained in the documentation above.

If the `ryax_metadata.yaml` file contains unknown fields, an error is thrown.



