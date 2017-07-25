Explanation of verification process:
==================================== 
An Android application (app) is implemented in a set of callbacks which are invoked by the framework.  These callbacks are invoked to indicate state changes and events that the app can respond to.  The responses take the form of method invocations on the framework or “callins”.  Our process starts by exercising an app either manually or with the Android UI tester monkey.  This trace can then be combined with a set of rules and encoded in a model. The steps of our verification are listed below and the intermediate files section contains the description of the input to nuXmv.

Tools:
======
We have two main tools: “Trace Runner” and “Callback Verification”. These are internal names, in publication we will refer to them both as VeriVita.  TraceRunner creates the traces and Callback Verification checks for the defects.  We can provide access to these repos with a Github username.

https://github.com/cuplv/TraceRunner
https://github.com/cuplv/callback-verification/


Trace Runner: 
===============
This tool is what is used to collect the trace, it takes an APK file and generates a new instrumented APK file. The new APK file can be loaded and run on a phone and will send the trace data over a network socket.  More details for this process can be provided if needed, but we will assume that you are working with the trace we have provided.

Callback Verification:
==================
This tool is what takes a trace, a set of rules, and produces the verification result. 
Inputs:
---------
-	Trace: this is a sequence of callbacks where each callback contains a sequence of callins. This is a relatively complete picture of the communication between the application and the Android framework during normal operation of an app.  However, it does not capture the internal execution of the app beyond what callins it invoked.
		Trace for yamba is located here: input/trace-MainActivity-debug_2017-04-25_16:35:41
-	Enable specs: these are hand written using our “Lifestate” language that encodes properties of the framework related to callback ordering.  These hand-written rules are validated against the observed traces checking for behaviors which are contradictory to the written rules.  This check is done on as many observed traces as possible to assure that the model is as sound as is possible with respect to the behavior seen so far.  The precision of these specs is checked by observing how many false alarms are removed.
		All files in input/enable_specs/
-	Allow specs: these are handwritten with a very similar syntax to the enabled specs but encode error conditions related to invoking methods in unfavorable states of the framework.
		Input/allow_specs/dismiss.spec



Invocation:
-----------
python driver.py –m ic3 –t [trace] –s [spec file list] --ic3_frames 40 -n [nuxmv path] -z

flags:
-------
-	-m : selection of mode, in this case “-m ic3” says to use IC3 to check the transition system.  Other modes include “simulation” which checks that the rules do not contradict observed behavior in that trace, bmc for checking using bounded model checking, or check-files to print the trace for manual inspection.
-	-t : trace file output from TraceRunner
-	-s : spec file list separated by semicolons, both enable and allow specs are listed here.
-       -ic3_frames : frame parameter which can be tuned
-       -n : path to nuXmv executable
-       -z : enable trace simplification

Possible outputs:
-----------------------
-	Safe : the trace cannot be rearranged to find a defect
-	Counter example: This will list a sequence of callbacks which are possible within the enable specs which lead to an error condition specified by the allow specs. (described in "Reading the output")

Intermediate files 
------------------------
(these are normally temp files which are generated and deleted at the end of the run):

-	model/yamba.smv: This is the transition system generated from the trace and the rules.  It is hard to read on its own since it is compiled automatically.
-	model/command.cmd: command file
-	simplified_models/ : This directory contains the models which have been made more readable.  It also contains its own readme describing the details of the files.
Running nuXmv: 
----------------------

nuXmv -source command.cmd yamba.smv

Reading the output:
---------------------------
The output of our tool is listed in verifier_result.txt.  This is automatically generated from the output of running nuXmv (or other tools which we encode the problem for) combined with information from the original trace and specifications.

sections of output:
-	Grounding statistics: grounding is the process of filling in the variables in specifications with concrete values observed in the trace.  The field total number of specs (before grounding) is the specs which are read in.  This number is much larger than what we wrote manually due to some automation in generating common patterns.  Total specs after grounding is the specs that could be matched to parts of the trace.
-	Trace statistics: This shows general information about the size of the trace. 
-	Simplified trace: This is a simplified trace which drops all of the callins which are not mentioned by the spec.  Additionally we drop callbacks which are not mentioned by the specification and do not contain any callins which are mentioned by the specification.  An unspecified callback can be placed anywhere in the trace and duplicated by the verifier to be sound.  After the simplified trace itself is a similar trace statistics section after simplification.
-	Counterexample: This shows a sequence of callbacks and callins which are possible based on the enable rules that can reach the exception.  The counterexample shows at each step the rules which applied to help with debugging both the specification and the app.  This counterexample is a human readable decoding of the nuXmv output based on the specs and input trace.


Brief description of the defect in yamba:
-------------------------------------------------------
The defect in the Learning-android Yamba app comes from a misuse of a Dialog object used for interacting with a dialog displayed to the user.  The Dialog.dismiss() method is used to hide the dialog, but must only be called while the parent Activity object is in a resumed state.  In this particular example the developer uses an AsyncTask to do some network operations and invoke a callback (onPostExecute) on completion.  This callback dismisses a dialog which was used to show the user that the network operation was running.  It is possible for the user to click the button while the dialog is showing, then the dialog is paused while the background task is running and finally the onPostExecute callback is invoked causing the defect.

```
class PostTask extends AsyncTask{
    void onPreExecute(){
        progress = ProgressDialog.show(getActivity(), …); //Activity comes from getActivity()
    }
    void doInBackground(){
        … // network task running in background.
    }
    void onPostExecute(){
        progress.dismiss(); //Dialog.dismiss() can be called after the activity has been paused
    }
}

void onClick(){
    (new PostTask()).execute() //A clickListener triggers the AsyncTask.
}
```
