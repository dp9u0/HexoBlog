---
title: tag plugins
date: 2017-02-22 17:23:59
categories:
- knowledge
tags:
- hexo
---

# blockquote

## Example 1.1 : No arguments. Plain blockquote.

{% blockquote %}
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque hendrerit lacus ut purus iaculis feugiat. Sed nec tempor elit, quis aliquam neque. Curabitur sed diam eget dolor fermentum semper at eu lorem.
{% endblockquote %}

## Example 1.2 : Quote from a book

{% blockquote Seth Godin http://sethgodin.typepad.com/seths_blog/2009/07/welcome-to-island-marketing.html Welcome to Island Marketing %}
Every interaction is both precious and an opportunity to delight.
{% endblockquote %}

## Example 1.3 :　Quote from Twitter

{% blockquote @DevDocs https://twitter.com/devdocs/status/356095192085962752 %}
NEW: DevDocs now comes with syntax highlighting. http://devdocs.io
{% endblockquote %}

## Example 1.4 :　Quote from an article on the web

{% blockquote Seth Godin http://sethgodin.typepad.com/seths_blog/2009/07/welcome-to-island-marketing.html Welcome to Island Marketing %}
Every interaction is both precious and an opportunity to delight.
{% endblockquote %}

# codeblock

## Example 2.1 : A plain code block

{% codeblock %}
alert('Hello World!');
{% endcodeblock %}

## Example 2.2 : Specifying the language

{% codeblock lang:objc %}
[rectangle setX: 10 y: 10 width: 20 height: 20];
{% endcodeblock %}

## Example 2.3 : Adding a caption to the code block

{% codeblock Array.map %}
array.map(callback[, thisArg])
{% endcodeblock %}

## Example 2.4 : Adding a caption and a URL

{% codeblock _.compact http://underscorejs.org/#compact Underscore.js %}
_.compact([0, 1, false, 2, '', 3]);
=> [1, 2, 3]
{% endcodeblock %}

