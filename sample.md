<!-- bg: images/jl1.jpg -->

# Screen Presenter

A minimal overlay for macOS.

Move your mouse to the **top-right corner** to open.

---

## Controls

- **Space** or **→** — next slide
- **←** — previous slide
- **Esc** or click outside — dismiss

---

## Two-column slide

Use `|||` on its own line to split a slide.

- Text flows independently
- Columns render side-by-side
- Spacing is automatic

|||

![tap dancer](images/Clumsy tap dancer in action.png)

---

## Inline image

![predator](images/Predator's awkward tap dance showdown.png)

Paths are relative to the `.md` file.

---

## Syntax highlighting

```swift
struct Slide {
    let background: String?
    let columns: [String]
}

func render(_ slide: Slide) -> some View {
    Text(slide.columns.first ?? "")
        .font(.system(size: 24))
}
```

Fenced blocks — supply a language after the opening fence.

---

## Two-column code

Explanation of the snippet.

- Uses Highlightr
- Theme: atom-one-dark
- 190+ languages

|||

```python
def fib(n):
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

---

<!-- bg: images/jl1.jpg -->

# Background image

Use `<!-- bg: path -->` anywhere in a slide.

A dark overlay is applied automatically for readability.

---

<!-- bg: images/jl1.jpg -->

## Background + columns

Background image shows through both columns.

|||

![tap dancer](images/Clumsy tap dancer in action.png)
