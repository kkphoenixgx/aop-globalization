 => ERROR [6/8] RUN cp -r /repo/test/development/all_features/* /app/                                                                                                                    0.2s 
------                                                                                                                                                                                        
 > [6/8] RUN cp -r /repo/test/development/all_features/* /app/:                                                                                                                               
0.203 cp: cannot stat '/repo/test/development/all_features/*': No such file or directory
------

 1 warning found (use docker --debug to expand):
 - JSONArgsRecommended: JSON arguments recommended for CMD to prevent unintended behavior related to OS signals (line 18)
Dockerfile:9
--------------------
   7 |     
   8 |     WORKDIR /app
   9 | >>> RUN cp -r /repo/test/development/all_features/* /app/
  10 |     
  11 |     # Build the C++ test
--------------------
ERROR: failed to build: failed to solve: process "/bin/sh -c cp -r /repo/test/development/all_features/* /app/" did not complete successfully: exit code: 1
