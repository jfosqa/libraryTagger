# Bug Reports
### we will work from this list to triage and prioritize bugs

Format to follow Description, Priority, Severity, Steps to Repro, Expected Results, Actual Results

##Workflow:
1. Review the bug
2. Determine Root Cause
3. Review tests, how did we miss this?
4. Develop plan for resolution and testing
5. Implement and execute tests first (red/green)
6. Implement fix (comment in code outlining bug fix issue number)
7. Update this document:
 7a. Set Issue Status = Closed
 7b. Update Root Cause

###Priorities
P1: Must fix - critical to functionality usage. Performance issues.
P2: Should Fix - important to functionality usage, but does not prevent use. User Experience issues.
P3: Fix when able - nice to have, improves quality of life

###Severities
Blocker: Prevents user from completing workflow
Critical: Impacts user workflow, but has a frustrating workaround
Major: Disrupts user workflow, has a workaround
Minor: Edge/Corner cases
Trivial: Nice to have

##Issues
###Issue 0001
Description: Entering multiple partial terms in the search dialog results in a potential race condition:
Priority: ==P1==
Severity: ==Blocker==
Status: ==Open==
Root Cause: ==TBD==

Steps to reproduce:
1. Open the Directed Search Dialog
2. First filter: Name contains rush
3. Second filter: Genre Contains drum
4. Click Search

Expected Results: A list of tracks come back where the Name contains rush (example Ed Rush or ed_rush) and the genre contains drum (example Drum & Bass)

Actual Results: Exception thrown in debugger Exception    NSException *    "-[ITLibAlbum valueForProperty:]: unrecognized selector sent to instance 0x7bbb68fc0"    0x00000007bbbdc360

libsystem_kernel.dylib`__pthread_kill:
    0x1863795a8 <+0>:  mov    x16, #0x148               ; =328 
    0x1863795ac <+4>:  svc    #0x80
->  0x1863795b0 <+8>:  b.lo   0x1863795d0               ; <+40>
    0x1863795b4 <+12>: pacibsp 
    0x1863795b8 <+16>: stp    x29, x30, [sp, #-0x10]!
    0x1863795bc <+20>: mov    x29, sp
    0x1863795c0 <+24>: bl     0x1863715e4               ; cerror_nocancel
    0x1863795c4 <+28>: mov    sp, x29
    0x1863795c8 <+32>: ldp    x29, x30, [sp], #0x10
    0x1863795cc <+36>: retab  
    0x1863795d0 <+40>: ret    

###Issue 0002
Description: Enabling a Filter option in the list should enable the parent toggle
Priority: ==P3==
Severity: ==Trivial==
Status: ==Open==
Root Cause: ==TBD==

Steps to reproduce:
1. Open the Filter Dialog from the results table
2. Scroll Down to Alerts
3. Click to enable "Dash Separator"

Expected Results: Dash Separator is Enabled and the Parent enable for Alerts is toggled on

Actual Results: User can't click

###Issue 0003
Description: List filters are not resetting when the user executes a new search
Priority: ==P1==
Severity: ==Critical==
Status: ==Closed==
Root Cause: `resultsFilter` state in ContentView was not cleared when initiating a new scan, directed search, or clicking New Search/Start Over. Added `resultsFilter.clear()` to all four reset paths.

Steps to reproduce:
1. Execute a search operation
2. Open the Results filter, enable Alerts->Dash Separator
3. Verify the list is filtered to show only those items with Dash Separator alerts (or whatever was chosen - this applies to ALL filter sections)
3. Click the New Search button

Expected Results: The list filter is automatically cleared and an unfiltered list is returned to the user.

Actual Results: The user receives a filtered list. In some cases, this could be empty.
