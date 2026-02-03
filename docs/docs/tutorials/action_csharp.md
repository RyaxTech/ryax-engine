# Create C# Action

**WARNING**: This is a feature preview, we look forward for your feedback!

Ryax now supports actions written in **C# (Csharp) with DotNet 6**.

To create a C# action just create a Dotnet project and go inside with:
```
dotnet new console -o App -n MyAction
cd App
```

Then add your dependencies, for example:
```
dotnet add package Newtonsoft.Json
```

Now edit the `Program.cs` file to add your code. Here is an example:
```cs
using System;
using System.Diagnostics;

namespace Ryax {
    class Rectangle {

        // member variables
        public double length;
        public double width;

        public double GetArea() {
            return length * width;
        }
        public void Display() {
            Console.WriteLine("Length: {0}", length);
            Console.WriteLine("Width: {0}", width);
            Console.WriteLine("Area: {0}", GetArea());
        }
    }
    class Handler {
        public static Dictionary<string, object> handler(Dictionary<string, object> inputs) {
            Console.WriteLine("Inputs:");
            foreach (var item in inputs)
            {
                Console.WriteLine("- {0}: {1}", item.Key, item.Value);
            }

            Rectangle r = new Rectangle();
            r.length = (double) inputs["length"];
            r.width = (double) inputs["width"];
            r.Display();

            var outputs = new Dictionary<string, object>() {
                {"area", r.GetArea()}
            };

            return outputs;
        }
    }
}
```

To allow Ryax to find the entrypoint of your program it requires you to create
a `Ryax.Handler.handler` method that take a Dictionary as input and returns
also a Dictionary.

Now create a `ryax_metadata.yaml` file where you define inputs and outputs with
some description of your Ryax action and you're done! Don't forget to set the
type to `type: csharp-dotnet6` :)

```yaml
apiVersion: "ryax.tech/v2.0"
kind: Processor
spec:
  id: rectanglearea
  human_name: Csharp Rectangle Area
  type: csharp-dotnet6
  version: "1.2"
  description: "Csharp example action"
  categories:
  - Test
  inputs:
    - help: Width
      human_name: Rectangle Width
      name: width
      type: float
    - help: Length
      human_name: Rectangle Length
      name: length
      type: float
  outputs:
    - help: Rectangle Area
      human_name: Area
      name: area
      type: float
```

You can see the complete example [here](https://gitlab.com/ryax-tech/ryax/ryax-action-wrappers/-/tree/master/examples/csharp-rectangle)
