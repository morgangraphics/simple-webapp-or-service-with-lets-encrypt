# Contributing to the repo

The following is a set of guidelines for contributing to this repo and the cause, These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this and all documents in a pull request.

## What is the the purpose?

As stated in the [README](README.md#goals) section, the primary purpose of this article is to create a recipe of simple, clearly defined steps for setting up a application server **securely** with Let's Encrypt and Certbot. It is meant to educcate as-well-as be as Copy + Paste friendly as possible to take the guess work out of the process.

The recipe is intentionally generic (after installing Certbot), meaning, with the limited exceptions of setting [iptables rules](iptables.md) there is little to no Operating System specific work here. The purpose is to reduce complexity of Linux distribution specific configuration. If you feel that this article doesn't do any specific Linux Distribution justice, file an issue explainign your position

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for the repo. Following these guidelines helps myself and the community understand the issue at hand, reproduce the behavior, and find related issues.

We empluoy a menthodology called Defend Your Decision (DYD). If you have an issue with a step, missing step, accuracy of claims, etc., we ask that you file a bug and offer supporting evidence to back your claims.

#### Issues with current process

Bugs are tracked as [GitHub issues](https://guides.github.com/features/issues/). After you've determined which step your bug is related to, create an issue and provide the following information by filling in the template.

Explain the problem and include any and all additional details to help maintainers reproduce the problem:

-   Use a clear and descriptive title for the issue to identify the problem.
-   Describe the exact step(s) which reproduce the problem in as many details as possible. For example, start by explaining the Operating System you are using and the version of the Operating System. More details help track down the issues.

Remember, the goal is to keep things as simple and as secure as possible.

#### Adding to the current process

The process is very well vetted, if you would like to add a step to improve or harden the process etc., we ask that you file a bug and offer supporting evidence to back your claims. DYD is meant to foster a conversation about improvements. As such, well construccted arguments are taken seriously and held with high regard.

## Pull Requests

The process described here has several goals:

-   Maintain quality
-   Fix problems that are important to users
-   Engage the community in working toward the best possible Atom


Please follow these steps to have your contribution considered by the maintainers:

-   Follow all instructions in the template
-   Follow the styleguides
-   While the prerequisites above must be satisfied prior to having your pull request reviewed, the reviewer(s) may ask you to complete additional design work, tests, or other changes before your pull request can be ultimately accepted.

## Styleguides


### Headers
Large Headers are generated at [https://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=](https://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=) using the ANSI Shadow font With Default settings for Character Width and Height

### Codeblocks
ASCII art codeblocks are

\```
terminal

\```

blocks

while the command line are

\```
bash

\```

blocks

### Git Commit Messages

-   Use the present tense ("Add feature" not "Added feature")
-   Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
-   Limit the first line to 72 characters or less
-   Reference issues and pull requests liberally after the first line

### Linting

We use the [Remark linter](https://github.com/remarkjs/remark)



Many thanks to the [Atom Project](https://github.com/atom/atom/blob/master/CONTRIBUTING.md) for the framework for this CONTRIBUTING.md file
