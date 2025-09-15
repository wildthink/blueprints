# TAL (Template Attribute Language) Guide

A simple XML-based templating system for HTML.

## Basic Setup

Add the TAL namespace to your HTML:
```html
<html xmlns:tal="http://xml.zope.org/namespaces/tal">
```

## Core Directives

### `tal:content` - Replace element content
```html
<h1 tal:content="page.title">Default Title</h1>
<!-- Output: <h1>My Page Title</h1> -->
```

### `tal:replace` - Replace entire element
```html
<span tal:replace="user.name">Guest</span>
<!-- Output: John Doe -->
```

### `tal:condition` - Conditional rendering
```html
<div tal:condition="user.isLoggedIn">Welcome back!</div>
<!-- Only renders if user.isLoggedIn is true -->
```

### `tal:repeat` - Loop over collections
```html
<li tal:repeat="item items" tal:content="item.name">Item</li>
<!-- Generates one <li> for each item -->
```

### `tal:attributes` - Set attributes dynamically
```html
<a tal:attributes="href user.profileUrl">Profile</a>
<!-- Output: <a href="/users/123">Profile</a> -->
```

## Template Inheritance

### Base Template (layouts/base.html)
```html
<html xmlns:tal="http://xml.zope.org/namespaces/tal">
<body>
    <header>Site Header</header>
    <main tal:slot="content">Default content</main>
    <footer>Site Footer</footer>
</body>
</html>
```

### Child Template (pages/home.html)
```html
<div xmlns:tal="http://xml.zope.org/namespaces/tal"
     tal:extends="layouts/base.html">
    <main tal:slot="content">
        <h1>Home Page</h1>
        <p>Welcome to our site!</p>
    </main>
</div>
```

## Output Modifiers

Use pipe syntax for content transformation:

```html
<h1 tal:content="title|upper">title</h1>
<!-- Converts to uppercase -->

<div tal:content="html_content|raw">content</div>
<!-- Renders without HTML escaping -->

<p tal:content="description|trim|capitalize">text</p>
<!-- Chains multiple modifiers -->
```

Available modifiers: `raw`, `upper`, `lower`, `trim`, `capitalize`

## Context Variables

Access data passed to the template:

```html
<!-- Simple values -->
<span tal:content="site.name">Site Name</span>

<!-- Nested objects -->
<span tal:content="user.profile.email">email</span>

<!-- Arrays/collections -->
<ul>
    <li tal:repeat="tag article.tags" tal:content="tag">tag</li>
</ul>
```

## Defaults and Fallbacks

Use `|default:` for fallback values:
```html
<h1 tal:content="page.title|default:'Untitled'">Title</h1>
<img tal:attributes="src user.avatar|default:'/images/default.png'"/>
```

## Directive Precedence

TAL processes directives in this order:
1. `tal:define`
2. `tal:condition`
3. `tal:repeat`
4. `tal:content` / `tal:replace`
5. `tal:attributes`

## Tips

- TAL attributes are removed from final output
- Content inside TAL elements serves as fallback for invalid templates
- Use `tal:condition="exists:variable"` to check if variable exists
- Combine multiple attributes: `tal:condition="user" tal:content="user.name"`