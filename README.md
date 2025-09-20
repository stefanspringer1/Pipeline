# Pipeline

This is a simple framework for constructing a pipeline to process a single work item.

## Overview

The idea is that there is no fixed declarative schema for composing the steps of a processing pipeline for a single work item, as any conceivable schema might not be flexible enough. Instead, the concept is simply “functions calling functions,” with specific functions acting as steps. This gives you everything you need to define, control, and log a processing pipeline with maximum flexibility and efficiency.

The framework is designed to also handle steps defined in other packages. It can reduce errors that occur in called steps to a specific severity level, which is very useful e.g. if a fatal error in another package should be treated as just a normal error in your application.

The problem of prerequisites for a step (things that must be done beforehand) is solved in a simple way: A step can call other steps before completing its own work, but these steps (like all steps in general) will only be executed if they have not been executed previously. (You can change this behavior for a specific section of code by “forcing” execution.)

To facilitate further description, we will already introduce some of the types used. You define a complex processing of one “work item” that can be executed within an `Execution` environment. For each work item a separate `Execution` instance has to be created. If more than one work item is to be processed, then more than one `Execution` instance has to be used.

This framework does not provide its own logging implementation. However, the logging used by packages should be able to be formulated independently of the actual logging implementation. Log messages can therefore be generated via methods of the `Execution` instance and then must be processed by an `ExecutionInfoConsumer` provided by you. The `ExecutionInfoConsumer` must also handle information about the execution of the steps. This information is contained in the `ExecutionInfo` type, which the `ExecutionInfoConsumer` must be able to process. More granular error types are available than in most actual logging implementations, which you must then map to the message types of the logging implementation used by your application.

Concerning metadata such as a “process ID”, the pipline steps should not need to know about it. The `ExecutionInfoConsumer` should handle any metadata and add it to the actual log entries if required.

The implementation of `ExecutionInfo` contains methods that simplify the creation of an actual text log entry. Cf. the implementation of `ExecutionInfoConsumerForLogger` in the test cases, which are generally a good way to see the features of this framework in action.

The framework can also handle the parallel processing of partial work items and handle asynchronous calls (see the section about working in asynchronous contexts).

This documentation contains some motivation. For a quick start, there is a tutorial below. For more details, you might look at the conventions (between horizontal rules) given further below and look at some code samples from the contained tests.

The API documentation is to be created by using DocC, e.g. in Xcode via „Product“ / „Build Documentation“.

The `import Pipeline` and other imports are being dropped in the code samples.

## How to add the package to your project

The package is to be inlcuded as follows in another package: in `Package.swift` add:

The top-level dependency:

```Swift
.package(url: "https://github.com/stefanspringer1/Pipeline", from: "...put the minimal version number here..."),
```

(You might reference an exact version by defining e.g. `.exact("0.0.1")` instead.)

As dependency of your product, you then just add `"Pipeline"`.

As long as the [concise magic file name](https://github.com/apple/swift-evolution/blob/main/proposals/0274-magic-file.md) is not yet the default for your Swift version, you need to enable it via the following [upcoming feature flag](https://www.swift.org/blog/using-upcoming-feature-flags/) for your target:

```Swift
swiftSettings: [
    .enableUpcomingFeature("ConciseMagicFile"),
]
```

The Workflow package will be then usable in a Swift file after adding the following import:

```Swift
import Pipeline
```

## Tutorial

The first thing you need it an instance to process messages from the execution, reporting if a step has beeen begun etc. The processing of these messages always has to be via a simple synchronous methods, no matter if the actual logging used behind the scenes is asynchronous or not. Most logging environment are working with such a synchronous method.

You need an instance conforming to `ExecutionInfoConsumer`

```Swift
public protocol ExecutionInfoConsumer {
    func consume(_ executionInfo: ExecutionInfo)
    var metadataInfo: String { get }
}
```

If the metadata information is actually needed during processing (in the general case, this should not be the case), it can be requested via the `metadataInfo` property of the `Execution` which in turn gets the information from the `ExecutionInfoConsumer`. Note that in the general case the metadata should contain the information about the current work item, so not only a new `Execution` has to be created for each work item, but usually also a new `ExecutionInfoConsumer` has to be created.

See the `ExecutionInfoConsumerForLogger` example in the test cases.

Then, for each work item that you want to process (whatever your work items might be, maybe you have only one work item so you do not need a for loop), use a new `Execution` object:

```Swift
let logger = PrintingLogger()
let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger)

let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
```

The step you call (in the following example: `myWork_step`) might have any other arguments besides the `Execution` and some logger, and the postfix `_step` is only for convention. Your step might be implemented as follows:

```Swift
func myWork_step(during execution: Execution) {
    execution.effectuate(
        "...here a description can be added...",
        checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)
    ) {
        
        // ... some other code...
        
        myOther_step(during: execution)
        
        // ... some other code...
        
    }
}
```

The value `StepID(crossModuleFileDesignation: #file, functionSignature: #function)` of the `checking:` argument is used to uniquely identify the step.

`#file` should denote the [concise magic file name](https://github.com/apple/swift-evolution/blob/main/proposals/0274-magic-file.md) `<module-name>/<file-name>` (you might have to use the [upcoming feature flag](https://www.swift.org/blog/using-upcoming-feature-flags/) `ConciseMagicFile` for this, see the `Package.swift` file of this package).

I.e. you embrace the content of your function inside a `execution.effectuate` call so that the `Execution` instance can control and inform about the execution of your code. The `StepID` instance is used as a unique identifier for your step.

---

NOTE:

There is also a macro to just annotate a function with `@Step` so you do not have to add the `execution.effectuate` code yourself, but there are still an issue with this macro that needs to resolved (the placement of error annotations is not correct).

---

The call of this step is then as follows:

```Swift
myWork_step(during: execution)
```

_Note that in order to be able to use future enhancemants of the library, you should not have code outside this single call of `effectuate` in your function!_

Inside your step you might call other steps. In the example above, `myOther_step` has the same arguments as `myWork_step`, but in the general case, this does not have to be this way. On the contrary, our recommendation is to only give to each step the data that it really needs.

If you call `myOther_step` inside `myWork_step` as in the example above, `myOther_step` (or more precisely, the code inside it that is embraced in a `execution.effectuate` call) will not be executed if `myWork_step` has already been executed before during the same execution (of the work item). This way you can formulate prerequisites that should have been run before, but without getting the prerequisites executed multiple times. If you want to force the execution of `myOther_step` at this point, use the following code:

```Swift
execution.force {
    myOther_step<(during: execution)
}
```

You can also disremember what is executed with the following call:

```Swift
execution.disremember {
    myOther_step(during: execution)
}
```

There are also be named optional parts that can be activated by adding an according value to the `withOptions` value in the initializer of the `Execution` instance:

```Swift
execution.optional(named: "module1:myOther_step", description: "...here a description can be added...") {
        myOther_step(during: execution)
}
```

On the contrary, if you regard a step at a certain point or more generally a certain code block as something dispensable (i.e. the rest of the application does not suffer from inconsistencies if this part does not get executed), use the following code: 

```Swift
execution.dispensable(named: "module1:myOther_step", description: "...here a description can be added...")) {
        myOther_step(during: execution)
}
```

The part can then be deactivated by adding the according name to the `dispensingWith` value in the initializer of the `Execution` instance.

So with `execution.optional(named: ...) { ... }` you define a part that does not run in the normal case but can be activated, and with `execution.dispensable(named: ...) { ... }` you define a part that runs in the normal case but can be deactivated. It is recommended to add the module name to the part name as a prefix in both cases.

An activated option can also be dispensed with („dispensing wins“).

If your function contains `async` code (i.e. `await` is being used in the calls), use `AsyncExecution` instead of `Execution` or `execution.async.force`. Inside an `AsyncExecution`, you get the according `Execution` instance via `myAsyncExecution.synchronous`, so you can asynchronous steps at the outside that are calling  synchronous steps in the inside.

The texts `$0`, `$1`, ... are being replaced by arguments (of type `String`) in their order in the call to `execution.log`.

## Motivation

We think of a processing of a work item consisting of several steps, each step fullfilling a certain piece of work. We first see what basic requirements we would like to postulate for those steps, and then how we could realize that in practice.

### Requirements for the execution of steps

The steps comprising the processing might get processed in sequence, or one step contains other steps, so that step A might execute step B, C, and D.

We could make the following requirements for the organization of steps:

- A step might contain other steps, so we can organize the steps in a tree-like structure.
- Some steps might stem from other packages.
- A step might have as precondition that another step has already been executed before it can do some piece of work.
- There should be an environment accessible inside the steps which can be used for logging (or other communication).
- This environment should also have control over the execution of the steps, e.g. when there is a fatal error, no more steps should be executed.

But of course, we do not only have a tree-like structure of steps executing each-other, _somewhere_ real work has to be done. Doing real work should also be done inside a step, we do not want to invent another type of thing, so:

- In each step should be able to do real work besides calling other steps.

We would even go further:

- In each step, there should be no rules of how to mix “real work” and the calling of other steps. This should be completely flexible.

We should elaborate this last point. This mixture of the calling of steps and other code may seem suspicious to some. There are frameworks for organizing the processing which are quite strict in their structure and make a more or less strict separation between the definition of which steps are to be executed and when, and the actual code doing the real work. But seldom this matches reality (or what we want the reality to be). E.g. we might have to decide dynamically during execution which step to be processed at a certain point of the execution. This decision might be complex, so we would like to be able to use complex code to make the decision, and moreover, put the code exactly to where the call of the step is done (or not done).

We now have an idea of how we would like the steps to be organized.

In addition, the steps will operate on some data to be processed, might use some configuration data etc., so we need to be able to hand over some data to the steps, preferably in a strictly typed manner. A step might change this data or create new data and return the data as a result. And we do not want to presuppose what types the data has or how many arguments are used, a different step might have different arguments (or different types of return values).

Note that the described flexibility of the data used by each step is an important requirement for modularization. We do not want to pass around the same data types during our processing; if we did so, we could not extract a part of our processing as a separate, independant package, and we would not be very precise of what data is required for a certain step.

### Realization of steps

When programming, we have a very common concept that fullfills most of the requirements above: the concept of a _function._ But when we think of just using functions as steps, two questions immediately arise:

- How do we fullfill the missing requirements?
- How can we visually make clear in the code where a step gets executed?

So when we use functions as steps, the following requirements are missing:

- A step might have as precondition that another step has already been executed before it can do some piece of work.
- There should be an environment accessible inside the steps which can be used for logging (or other communication).
- This environment should also have control over the execution of the steps, e.g. when there is a fatal error, the execution of the steps should stop.

We will see in the next section how this is resolved. For the second question ("How can we visually make clear in the code where a step gets executed?"): We just use the convenstion that a step i.e. a function that realizes a step always has the postfix "\_step" in its name. Some people do not like relying on conventions, but in practice this convention works out pretty well.

---
**Convention**

A function representing a step has the postfix `_step` in its name.

---

## Concept

### An execution

An `Execution` has control over the steps, i.e. it can decide if a step actually executes, and it can inform about what if happening. 

### Formulation of a step

To give an `Execution` control over a function representing a step, its statements are to be wrapped inside a call to `Execution.effectuate`.

---
**Convention**

A function representing a step uses a call to `Execution.effectuate` to wrap all its other statements.

---

We say that a step “gets executed” when we actually mean that the statements inside its call to `effectuate` get executed.

A step fullfilling "task a" is to be formulated as follows. In the example below, `data` is the instance of a class being changed during the execution (of cource, our steps could also return a value, and different interacting steps can have different arguments). The execution keeps track of the steps run by using _a unique identifier for each step._ An instance of `StepID` is used as such an identifier, which contains a) a designation for the file that is unique across modules (using [concise magic file name](https://github.com/apple/swift-evolution/blob/main/proposals/0274-magic-file.md)), and b) using the function signature which is unique when using only top-level functions as steps.

```Swift
func a_step(
    during execution: Execution,
    data: MyData
) {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
        
            execution.log(.info, "working in step a")
        
    }
}
```

---
**Convention**

- A function representing a step is a top-level function.
- Use the function signature available via `"\(#function)@\(#file.firstPathPart)"` as the identifier in the call of the `effectuate` method.

---

Let us see how we call the step `a_step` inside another step `b_step`:

```Swift
func b_step(
    during execution: Execution,
    data: MyData
) {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
        
        a_step(during: execution, data: data)
        
        execution.log(.info, "working in step b")
        
    }
}
```

Here, the call to `a_step` can be seen as the formulation of a requirement for the work done by `b_step`.

Let us take another step `c_step` which first calls `a_step`, and then `b_step`:

```Swift
func c_step(
    during execution: Execution,
    data: MyData
) {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
        
       a_step(during: execution, data: data)
       b_step(during: execution, data: data)
        
      execution.log(.info, "working in step c")
        
    }
}
```

Again, `a_step` and `b_step` can be seen here as requirements for the work done by `c_step`.

When using `c_step`, inside `b_step` the step `a_step` is _not_ being executed, because `a_step` has already been excuted at that time. By default it is assumed that a step does some manipulation of the data, and calling a step  says "I want those manipulation done at this point". This is very common in complex processing scenarios and having this behaviour ensures that a step can be called in isolation and not just as part as a fixed, large processing pipeline, because it formulates itself which prerequisites it needs.[^4]

[^4]: Note that a bad formulation of your logic can get you in trouble with the order of the steps: If `a_step` should be executed before `b_step` and not after it, and when calling `c_step`, `b_step` has already been executed but not `a_step` (so, other than in our example, `a_step` is not given as a requirement for `b_step`), you will get the wrong order of execution. In practice, we never encountered such a problem.

---
**Convention**

Requirements for a step are formulated by just calling the accordings steps (i.e. the steps that fullfill the requirements) inside the step. (Those steps will not run again if they already have been run.)

---


But sometimes a certain other step is needed just before a certain point in the processing, no matter if it already has been run before. In that case, you can use the `force` method of the execution:

```Swift
func b_step(
    during execution: Execution,
    data: MyData
) {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
        
        execution.force {
            a_step(during: execution, data: data)
        }
        
        execution.log(.info, "working in step b")
        
    }
}
```

Now `a_step` always runs inside `b_step` (if `b_step` gets executed).

Note that any sub-steps of a forced step are _not_ automatically forced. But you can pass a forced execution onto a sub-step by calling it inside `inheritForced`:

```Swift
func b_step(
    during execution: Execution,
    data: MyData
) {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
        
        execution.inheritForced {
            // this execution of a_step is forced if the current execution of b_step has been forced:
            a_step(during: execution, data: data)
        }
        
        execution.log(.info, "working in step b")
        
    }
}
```

---
**Convention**

Use the `Execution.force` method if a certain step has to be run at a certain point no matter if it already has been run before.

---

### How to return values

If the step is to return a value, this must to be an optional one:

```Swift
func my_step(
    during execution: Execution,
    data: MyData
) -> String? {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
        ...
        return "my result"
        ...
    }
}
```

Note that the `effectuate` method returns the according value, so there is no need to set up any variable outside the `effectuate` call.

_The optionality must stem from the fact that the execution might be effectuated or not._ If the code within the `effectuate` call is itself is meant to return an optional value, this has to be done e.g. via the `Result` struct:

```Swift
func my_step(
    during execution: Execution,
    data: MyData
) -> Result<String, ErrorWithDescription>? {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
        ...
        var value: String?
        ...
        if let value {
            return .success(value)
        } else {
            return .failure(ErrorWithDescription("the value is not set")))
        }
}
```

You can then check if (in the example) a `String` value is returned by e.g.:

```Swift
if case .success(let text) = my_step(during: execution:, data: MyData) {
    print(text)
}
```

### Outsourcing functionality into a new package

The tree-like pattern of steps that you are able to use in a workflow is a natural starting point to outsource some functionality of your workflow into an external package.

### Organisation of the code in the files

We think it a a sensible thing to use one file for one step. Together with the step data (which includes the error messages, see below), maybe an according library function, or a job function (see below), this "fits" very well a file in many case.

We also prefer to use folders with scripts according to the calling structure as far as possible, and we like to use a prefix `_external_` for the names of folders and source files if the contained steps actually call external steps i.e. library functions as described above.

### Limitations

This approach has as limitation that a library function is a kind of isolated step: From the view of a library function being called, there are no step functions that already have been run. In some cases, this limitation might lead to preparation steps done sevaral times, or certain prerequisites have to be formulated in the documentation of the library function and the according measures then taken in the wrapper of the library function. Conversely, to the outside not all that has been done by the library function might be taken into account in subsequent steps.

In practice we think that this limitation is not a severe one, because usually a library function is a quite encapsulated unit that applies, so to speak, some collected knowledge to a certain problem field and _should not need to know much_ about the outside.

### Jobs

Steps as described should be flexible enough for the definition of a sequence of processing. But in some circumstances you might want to distinguish between a step that reads (and maybe writes) the data that you would like to process, and the steps in between that processes that data. A step that reads (and maybe writes) the data would then be the starting point for a processing. We call such a step a “job” and give its name the postfix `_job` instead of `_step`:

```Swift
func helloAndBye_job(
    during execution: Execution,
    file: URL
) {
    
    // get the data:
    guard let data = readData_step(during: execution, file: file) else { return }
    
    // start the processing of the data:
    helloAndBye_step(during: execution, data: data)
}
```

So a job is a kind of step that can be called on top-level i.e. not from within another step.

It is a good practice to always create a job for each step even if such a job is not planned for the final product, so one can test each step separately by calling the according job.

### Using an execution just for logging

You might use an `Execution` instance ouside any step just to make the logging streamlined.

### Jobs as starting point for the same kind of data

Let us suppose you have jobs that all share the same arguments and the same data (i.e. the same return values) and you would like to decide by a string value (which could be the value of a command line argument) which job to start.

So a job looks e.g. as follows:

```Swift
typealias Job = (
    Execution,
    URL
) -> ()
```

In this case we like to use a "job registry" as follows (for the step data, see the section below):

```Swift
var jobRegistry: [String:(Job?,StepData)] = [
    "hello-and-bye": JobAndData(job: helloAndBye_job, stepData: HelloAndBye_stepData.instance),
    // ...
]
```

The step data – more on that in the next section – is part of the job registry so that all possible messages can be automatically collected by a `StepDataCollector`, which is great for documentation. (This is why the job in the registry is optional, so you can have messages not related to a step, but nevertheless formulated inside a `StepData`, be registered here under an abstract job name.)

The resolving of a job name and the call of the appropriate job is then done as follows:

```Swift
    if let jobFunction = jobRegistry[job]?.job {
        
        let logger = PrintingLogger()
        let myExecutionInfoConsumer = ExecutionInfoConsumerForLogger(withMetaDataInfo: metadata.description, logger: logger)
        let execution = Execution(executionInfoConsumer: myExecutionInfoConsumer)
        
        jobFunction(
            execution,
            URL(fileURLWithPath: path)
        )
    }
    else {
        // error...
    }
```

### Spare usage of step arguments

Generally, a step should only get as data what it really needs in its arguments. E.g. handling over a big collection of configuration data might ease the formulation of the steps, but being more explicit here - i.e. handling over just the parts of the configuration data that the step needs – makes the usage of the data much more transparent and modularization (i.e. the extraction of some step into a separate, independant package) easy.

### Step data

Each step should have an instance of `StepData` in its script with:

- a short description of the step, and
- a collection of message that can be used when logging.

When logging, only the messages declared in the step data should be used.

A message is a collection of texts with the language as keys, so you can define
the message text in different languages. The message also defines the type of the
message, e.g. if it informs about the progress or about a fatal error.

The message types (of type `MessageType`, e.g. `Info` or `Warning`) have a strict order, so you can choose the minimal level for a message to be logged. But the message type `Progress` is special: if progress should be logged is defined by an additional parameter.

See the example project for more details.

### Appeasing log entries

The error class is used when logging represents the point of view of the step or package. This might not coincide with the point of view of the whole application. Example: It is fatal for an image library if the desired image cannot be generated, but for the overall process it may only be a non-fatal error, an image is then simply missing.

So the caller can execute the according code in `execution.appease { … }`. In side this code, any error worse than `Error` is set to `Error`. Instead if this default `Error`, you can also specify the message type to which you want to appease via `execution.appease(to: …) { … }`. The original error type is preserved as field `originalType` of the logging event.

So using an "external" step would actually be formulated as follows in most cases:

```Swift
func hello_external_step(
    during execution: Execution,
    data: MyData
) {
    execution.effectuate(checking: StepID(crossModuleFileDesignation: #file, functionSignature: #function)) {
    
        execution.appease {
            hello_lib(during: execution, data: data)
        }
        
    }
}
```

### Stopping the execution

Usually the execution stops at a fatal or deadly error (you can change this behaviour by setting `stopAtFatalError: false` when initializing the `Execution`). That means that in such a case no new step is started.

The execution can also be informed via the `stop(reason:)` message that the execution should be stopped.

Note that any following code not belonging to any further step is still being executed.

### Working in asynchronous contexts

A step might also be asynchronous, i.e. the caller might get suspended. Let's suppose that for some reason `bye_step` from above is async (maybe we are building a web application and `bye_step` has to fetch data from a database):

```Swift
func bye_step(
    during execution: AsyncExecution,
    data: MyData
) async {
    ...
```

As mentioned above, you have to use `AsyncExecution`, and you can get call synchronous step with the `Execution` instance `execution.synchronous`.

### Parallel execution

Use `execution.parallel` to create a copy of an `execution` to use in a parallelization. Of course, you then need a logger that can handle conccurent logging.

See the example `parallelTest1()` in the tests.

Note that the parallel steps are not registered in the execution database. But the above code migth be part of anther step not executed in parallel, and that one will then be registered.

### Pause/stop

In order to pause or stop the execution of steps, appropriate methods of `Execution` are available. See the `pauseTest()` function in the tests.
