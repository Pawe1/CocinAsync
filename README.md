# CocinAsync #

A Delphi library to simplify coding and improve performance of asynchronous and multithreaded applications.

### Unit: cocinasync.async
*Inline coding helpers for implementing asynchronous actions*

This unit includes two synchronization helpers that make it easy to make sure code is executed in the main thread.  They automatically protect you from accidentally synchronizing from the main thread.

```
#!delphi

TAsync.SynchronizeIfInThread(
  procedure
  begin
    // Do something in the main thread
  end
);

TAsync.QueueIfInThread(
  procedure
  begin
    // Do something in the main thread
  end
);

```

Asynchronous operations can easily be performed inline in code.  The global Async object may be used when lifetime of the async operations is not dependent upon another object (like a form or data module).

```
#!delphi

Async.AfterDo(1000, 
  procedure
  begin
    // Execute this code after waiting 1s
  end
);

Async.DoLater(
  procedure
  begin
    // Execute this code at some point in the very near future.
  end
);

Async.OnDo(
  function : boolean
  begin
    // Check for some condition, return true if the due should be executed. False if it should not
  end,
  procedure
  begin
    // Executes only when the condition above has been met
  end,
  1000, // interval on which the check function should be called
  function : boolean
  begin
    // Return True to continue checking or False to abort
  end
);

Aync.DoEvery(1000,
  function : boolean
  begin
    // Execute this function every 1s. Return True to allow it to execute again or False to stop.
  end
);

```

When lifetime of an asynchronous operation depends upon another object such as a form or data module, create an instance of TAsync for that object.  If the global Async is used, then it's possible the asynchronous methods will be called after needed objects are freed.


```
#!delphi

procedure FormCreate(Sender : TObject);
begin
  FAsync := TAsync.Create;
  FAsync.DoEvery(10,
    procedure
    begin
      Shape1.Left := Random(Width-Shape1.Width);
    end
  );
end;

procedure FormDestroy(Sender : TObject);
begin
  FAsync.Free;
end;
```


### Unit: cocinasync.collections ###
*Lock-Free generic collection classes for high performance use in mutlithreaded applications*

* TQueue<T> - high performance queue collection that is thread safe without locking
* TStack<T> - high performance stack collection that is thread safe without locking
* THash<T> - high performance hash collection that is thread safe without locking

### cocinasync.global ###

*Utility objects*

### cocinasync.jobs ###

*A background job runner which easily executes tasks in the background*

### Contribution guidelines ###

* Fork and PR
* Fixes to the core library are welcome and encouraged
* Performance improvement PRs must be provable
* Additions to the library will be accepted if it furthers the project goal to simplify asynchronous and multithreaded development and to do so with a focus on high performance.

### MIT License ###

Copyright 2017 by Bugfish Limited

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

https://opensource.org/licenses/MIT