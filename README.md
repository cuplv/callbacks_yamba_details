# Verivita on Yamba Explanation

This repository contains some details on a bug found in the [Yamba] sample app from the O'Reilly _[Learning Android]_ book using the [Verivita] lifestate verification tool. The intent of this repository is to cache a run of [Verivita] to provide a quick way to explore its inputs and outputs without necessarily running the tool.

[Yamba]: https://github.com/learning-android/Yamba
[Learning Android]: http://www.worldcat.org/title/learning-android/oclc/868688441

[Verivita]: https://github.com/cuplv/callback-verification/ 

## Description of the Bug

The defect in the [Yamba] app comes from a misuse of a [Dialog] object on [line 183 of `StatusFragment.java`][Yamba Bug dismiss] (in this case a [ProgressDialog]).

A [Dialog] object represents a modal dialog in the user interface. The `Dialog.dismiss()` method is used to hide the dialog, but a pre-condition for calling this method is that the user interface is visible. That is, it must only be called while the parent [Activity] object is in a resumed state.

Here, the developer uses an [AsyncTask] to do some network operations, which invokes the callback `onPostExecute` on completion. This callback dismisses a dialog via `progress.dismiss()`, which was used to show the user that the network operation was running:

```java
      class PostTask extends AsyncTask<…> {
        private ProgressDialog progress;
      
        void onPreExecute() {
          // The parent Activity of progress comes from getActivity().
          progress = ProgressDialog.show(getActivity(), …);
        }
        void doInBackground() {
          … // This network task is running in background.
        }
        void onPostExecute() {
          // This Dialog.dismiss() can be called after the
          // parent Activity has been paused.
183:      progress.dismiss();
        }
      }
```

To fix some terminology, we refer to an app-implemented method that the framework invokes as a _callback_ (e.g., `PostTask.onPostExecute()`) and a framework-implemented method that the app invokes as a _callin_ (e.g., `Dialog.dismiss()`).

This [AsyncTask] is started by the user clicking a button in this click handler defined on [line 94][Yamba Bug onClick]:

```java
      ….setOnClickListener(new OnClickListener() {
 94:    public void onClick(View v) {
          … 
          PostTask postTask = new PostTask();
          postTask.execute(…);
          … 
        }
      });
```

But how could the UI not be visible when `progress.dismiss()` is called? Many ways, but one example is that rotating the phone temporarily makes the UI not visible while it is redrawn. If the completion of this `PostTask` and this redrawing happen to coincide, then the application crashes. It seems likely that this situation would be quite difficult to reproduce in testing.

This bug is quite insidious because even assuming the app developer has perfect knowledge on what protocol she should follow, the app developer has to think through, "I need to guarantee that `progress.dismiss()` is only called when progress is visible. So when is it possible for the `onPostExecute` handler to be triggered? Could it be triggered when progress is not visible?" And in this case, unfortunately yes. Worse yet, it would seem quite natural for even this knowledgeable app developer to wrongly assume that the framework would guarantee that progress is visible when `onPostExecute` is called—the `AsyncTask` was after all designed to make UI updates and background tasks "easy."

Supporting formal and tool-assisted reasoning of this form is the essence of Verivita.

[Dialog]: https://developer.android.com/reference/android/app/Dialog.html
[ProgressDialog]: https://developer.android.com/reference/android/app/ProgressDialog.html
[Activity]: https://developer.android.com/reference/android/app/Activity.html
[AsyncTask]: https://developer.android.com/reference/android/os/AsyncTask.html

[Yamba Bug dismiss]: https://github.com/learning-android/Yamba/blob/46795d3c4a1f56416f88a18b708d9db36a429025/src/com/marakana/android/yamba/StatusFragment.java#L183
[Yamba Bug onClick]: https://github.com/learning-android/Yamba/blob/46795d3c4a1f56416f88a18b708d9db36a429025/src/com/marakana/android/yamba/StatusFragment.java#L94

## Files

The key files cached in this repository consists of the following.

```
.
├── README.md
├── input/
│   ├── allow_specs/
│   ├── enable_specs/
│   └── trace-MainActivity-debug_2017-04-25_16:35:41
├── model/
│   ├── command.cmd
│   └── yamba.smv
├── simplified_models/
│   ├── simplified_model.smv
│   └── simplified_model_no_def.smv
└── verifier_result.txt
```

## Verification Inputs

Under [input/](input/), we have cached the verification input consisting of the following:

-	**Trace**. The trace is a sequence of callbacks where each callback contains a sequence of callins (and so forth). A trace for [Yamba] is [trace-MainActivity-debug_2017-04-25_16:35:41](input/trace-MainActivity-debug_2017-04-25_16:35:41).
-	**Allow specifications**. Allow specifications describe the pre-conditions for invoking callins (see [allow_specs/](input/allow_specs/)).
-	**Enable specifications**. Enable specifications encode when callbacks are "enabled," that is, when the app can assume a callback can or cannot be invoked (see [enable_specs/](input/enable_specs/)). To gain confidence in these specifications, we test them against all recorded traces to check that they indeed soundly model observed behavior.

## Trace Generation

Traces are created by a tool called [TraceRunner]. [TraceRunner] takes an Android Package Kit (APK) file and generates a new instrumented APK file. The new APK file can be loaded and run on a phone and will send the trace data over a network socket.

[TraceRunner]: https://github.com/cuplv/TraceRunner

## Output

The possible output of the verifier is "safe" or a counter-example. "Safe" means that no replication, removal, and rearrangement of the input trace could be find to witness a defect. If it not "safe", then a counter-example is given that lists a sequence of callbacks that could lead to an error. Concretely, the sequence respects the enable specifications and demonstrates a violation of the allow specifications.

Here, the counter-example showing the bug described above is given in [verifier_result.txt](verifier_result.txt). After some general statistics, there are two main sections in the output:

-	**Simplified trace**. This output shows a more readable and simplification of the input trace. The simplification drops all callins that are not mentioned by the specification.  Additionally, it drops callbacks that are not in the specification and do not contain any relevant callins.

  ```
---Simplified Trace---
[18] [CB] [ENTRY] void com.marakana.android.yamba.MainActivity.<init>() (43ae884) 
[18] [CB] [EXIT] NULL = void com.marakana.android.yamba.MainActivity.<init>() (43ae884) 
[62] [CB] [ENTRY] void com.marakana.android.yamba.MainActivity.onCreate(android.os.Bundle) (43ae884,NULL) 
  [1669] [CI] [ENTRY] void android.app.ListFragment.<init>() (eec2e40)
```

  The above shows the four three lines of the simplified trace from this example. It shows the `MainActivity` being constructed and then its `onCreate` callback being invoked. With in the `onCreate` callback, a `ListFragment` is constructed. The list at the end of the line in parentheses show the object identifiers.

-	**Counter-example**. This output shows a sequence of callbacks and callins that could lead to an error. The counter-example shows at each step the rules that applied to help with debugging both the specification and the app. This counter-example is a human-readable decoding of the nuXmv output based on the specifications and the input trace.

  ```
----------------------------------------
Step: 16
----------------------------------------
[13466] [CB] [ENTRY] void com.marakana.android.yamba.SubActivity.onPause() (b83e03e) 
    Matched specifications:
    ...
----------------------------------------
Step: 17
----------------------------------------
[13478] [CB] [ENTRY] void com.marakana.android.yamba.StatusFragment$PostTask.onPostExecute(java.lang.Object) (758671e,Please update your username and password) 
    Matched specifications:
    SPEC (((TRUE)[*]); [CB] [ENTRY] [758671e] void com.marakana.android.yamba.StatusFragment$PostTask.onPostExecute(Please update your username and password : java.lang.Object)) |- [CB] [ENTRY] [758671e] void com.marakana.android.yamba.StatusFragment$PostTask.onPostExecute(Please update your username and password : java.lang.Object)
----------------------------------------
Step: 18
----------------------------------------
[13479] [CI] [ENTRY] void android.app.Dialog.dismiss() (cc1bfcc) 
    Reached an error state in step 18!
```

  The above shows the final three steps showing the end of the error trace: `onPause` followed by `onPostExecute` followed by `dismiss`. The "matched specification" in step 17 says that the `onPostExecute` disables itself.

## Intermediate Model Files 

Intermediate nuXmv model files are given in [model/](model/) and [simplified_models/](simplified_models/). The nuXmv input [model/yamba.smv](model/yamba.smv) is the one that is normally generated as an intermediate step in the verifier.

This model is, however, hard to read because it is an optimized representation. Thus in [simplified_models/](simplified_models/), we attempt to generate some more readable models.

### More Readable nuXmV Models

The file [simplified_models/simplified_model.smv](simplified_models/simplified_model.smv) is a more human-readable version of
the SMV model than we usually generate when we verify a trace.

We changed the output of the our tool to produce this more human-readable version. The difference with the previous model format are as follows:

- It separates the different transition systems generated by the verifier. The verifier does not directly perform the (symbolic) composition of the transition systems, which is delegated to nuXmv. 

- It uses human readable names for the variables.

- It adds comments in front of the `MODULE` declarations to map the module back to the elements it encodes (e.g., the modules that encode a specification have a comment that shows the specification that they encode).

The model is, however, still hard to read for the following reasons:

- We encode the messages that label the transitions with as a set of Boolean variables. For example, to represent a variable that can be assigned to a value in the set `{1,2,3,4}`, we use two Boolean variables `b0` and `b1`, and we map an assignment to the Boolean variables to an element of the original domain (e.g., the assignment `b0 = False`, `b1 = False` is mapped to `1...`). Changing the encoding for debug purposes is non-trivial.
  
- The formulas are represented as Directed Acyclic Graphs (DAGs) by using SMV `DEFINE` directives. The file [simplified_models/simplified_model_no_def.smv](simplified_models/simplified_model_no_def.smv) is a version of [simplified_models/simplified_model.smv](simplified_models/simplified_model.smv) that prints a tree for the formulas. In the "tree" case, the formula printed in SMV is extremely large and thus may still be hard to read.

Both the SMV models can be verified reusing the same command file `command.cmd`:

```
$ nuXmv -source command.cmd ./simplified_model.smv
$ nuXmv -source command.cmd ./simplified_model_no_def.smv
```

#### Structure of the SMV model

The model is composed by several modules.

The `main` module declares the message variables used by the transition system.

A message is either a callin or a callback invocation, or the callin or callback returned value, logged from a concrete execution of the Android app.
A message variable is of Boolean type and when assigned to `true` represents that a message is enabled (if it is a callback invocation) or is allowed (if it is a callin invocation).

The `INIT` and `TRANS` constraints in the `main` module describe a transition system that, in each step of execution, chooses to execute the invocation of a callback or a callin. The transition system can execute a callback only if it is enabled. The transition system can choose to execute every callin: if the callin is not allowed, then the system moves in a sink state.

The `INVARSPEC` specification in the `main` module defines the "safe" states of the system. The specification holds if the transition system never executes a callin that is not allowed (and hence, does not reach the error sink state).

A trace also records the return value of callbacks and callins. Return values of callbacks and callins are also treated as messages.

The format of the name used for the message variables is: `enabled_<message>` where `<message>` is the callin or the callback. For example,

```
"enabled_[CB]_[ENTRY]_android.view.View com.marakana.android.yamba.TimelineFragment.onCreateView(android.view.LayoutInflater,android.view.ViewGroup,android.os.Bundle)(212079b,62c574e,NULL,NULL)" : boolean;
```

is the callback `com.marakana.android.yamba.TimelineFragment.onCreateView` from the trace that was invoked on the object `212079b` of type `android.view.View`, with arguments `62c574e`, `NULL`, `NULL`, of types `android.view.LayoutInflater`,`android.view.ViewGroup`,and `android.os.Bundle` respectively. The numbers `212079b` and `62c574e` are the addresses of the objects recorded in the concrete execution.

Each message has an `[ENTRY]` or `[EXIT]` specifier in the name, to determine if the message refers to the invocation or the return of a method.

The `main` module declares a set of input variables (`IVAR`declarations) to encode the message executed by the system when choosing a transition (i.e., the label on the transitions). The set of the labels is the set of messages seen in the concrete trace. For example, the message `enabled_[CI]_[ENTRY]_void
android.app.Dialog.dismiss()(cc1bfcc)` is part of the set of labels.

The set of input variables is named `_bit__msg_var__<n>` where `<n>` identifies a specific bit in the encoding. The correspondence between an assignment to the input variables and the message is kept by the tool, while it is hidden in the SMV model.

The `main` module further defines the constraints on the labels (i.e., the system can execute a transition labeled with a callback invocation only if the corresponding message variable is `true`).

The `main` module further instantiates different submodules, and the composition of all the constraints in the instantiated modules and in the `main` module is the transition system that encodes the dynamic verification problem.

The submodules in the `main` module are as follows:

- The submodule `m1` of type `mod1` defines all the possible reordering of the callbacks seen in the recorded trace.
  
  The possible reordering are then restricted by the constraints imposed by lifestate specifications.
  
- The submodules (named `m2` , ..., `m313` of type `mod2`, ..., `mod314`) encode the acceptance of a specification and the effect on the system when the regular expression is matched by the current execution.
  
  For example, the module `mod2` encodes the specification

  ```
(((TRUE)[*]); [CB] [ENTRY] [b83e03e] void com.marakana.android.yamba.SubActivity.onStop()) |+ [CB] [ENTRY] [b83e03e] void com.marakana.android.yamba.SubActivity.onDestroy()
```
 
  The specification says that, every time the system executes the callback

  ```
[CB] [ENTRY] [b83e03e] void com.marakana.android.yamba.SubActivity.onStop())
```

  then the callback

  ```
[CB] [ENTRY] [b83e03e] void com.marakana.android.yamba.SubActivity.onDestroy()
```

  must be enabled.
  
  The module encodes in the initial condition `INIT` and in the transition relation `TRANS` a deterministic automaton that accepts the language of the regular expression and that enables the

  ```
[CB] [ENTRY] [b83e03e] void com.marakana.android.yamba.SubActivity.onDestroy()
```

  message in the case.
  
- The submodule `mod314` encodes the frame condition of the message variables. Each specification defines when a message should be enabled/disabled or allowed/disallowed. If no specification is matched, the state of the message variables must not change in the system. This condition must be explicitly described in SMV.
