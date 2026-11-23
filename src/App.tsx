
import {
  ArrowRight,
  ArrowUpRight,
  Bot,
  Braces,
  Check,
  ChevronDown,
  Code2,
  Command,
  Cpu,
  FileCode2,
  Github,
  Layers3,
  Menu,
  Moon,
  ShieldCheck,
  Sparkles,
  Terminal,
  WandSparkles,
  Zap,
} from "lucide-react";
import { useState } from "react";
import "./App.css";

const features = [
  {
    icon: WandSparkles,
    title: "AI Script Generator",
    description:
      "Generate complete Lua scripts for your GTPS projects with intelligent AI assistance.",
    tag: "AI POWERED",
  },
  {
    icon: Code2,
    title: "Smart Code Editor",
    description:
      "Write, edit, and organize your Lua scripts in a dedicated development workspace.",
    tag: "DEVELOPMENT",
  },
  {
    icon: ShieldCheck,
    title: "GTPS API Knowledge",
    description:
      "Build with documented GTPS Cloud APIs. No invented functions or unreliable methods.",
    tag: "DOCUMENTATION",
  },
  {
    icon: Zap,
    title: "Code Optimizer",
    description:
      "Improve readability, structure, and performance without changing your script's behavior.",
    tag: "OPTIMIZATION",
  },
  {
    icon: Terminal,
    title: "Debug Assistant",
    description:
      "Understand errors, investigate issues, and find possible solutions faster.",
    tag: "DEBUGGING",
  },
  {
    icon: Layers3,
    title: "Project Workspace",
    description:
      "Keep your scripts and development projects organized in one place.",
    tag: "WORKSPACE",
  },
];

const codeLines = [
  { number: "01", content: "-- Welcome to Viemos", type: "comment" },
  { number: "02", content: 'local player = getPlayer()', type: "code" },
  { number: "03", content: "", type: "empty" },
  { number: "04", content: "if player then", type: "keyword" },
  { number: "05", content: '    print("Hello, developer!")', type: "string" },
  { number: "06", content: "end", type: "keyword" },
];

function App() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <div className="app-shell">
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />

      <header className="navbar">
        <a href="#" className="brand">
          <span className="brand-symbol">
            <Braces size={23} strokeWidth={2.5} />
          </span>
          <span>viemos<span className="brand-dot">.</span></span>
        </a>

        <nav className={menuOpen ? "nav-links nav-open" : "nav-links"}>
          <a href="#features" onClick={() => setMenuOpen(false)}>Features</a>
          <a href="#workflow" onClick={() => setMenuOpen(false)}>How it works</a>
          <a href="#about" onClick={() => setMenuOpen(false)}>About</a>
        </nav>

        <div className="nav-actions">
          <a
            className="github-link"
            href="https://github.com/ultrasyao/viemos"
            target="_blank"
            rel="noreferrer"
          >
            <Github size={17} />
            <span>GitHub</span>
          </a>
          <a href="#workspace" className="nav-cta">
            Get started <ArrowUpRight size={16} />
          </a>
        </div>

        <button
          className="mobile-menu"
          onClick={() => setMenuOpen(!menuOpen)}
          aria-label="Toggle navigation"
        >
          <Menu size={23} />
        </button>
      </header>

      <main>
        <section className="hero" id="about">
          <div className="hero-content">
            <div className="announcement">
              <span className="announcement-pulse" />
              <span>THE DEVELOPMENT SPACE FOR GTPS CREATORS</span>
              <ArrowUpRight size={14} />
            </div>

            <h1>
              Build smarter.
              <br />
              <span className="gradient-text">Code better.</span>
            </h1>

            <p className="hero-description">
              An AI-powered development workspace for GTPS creators.
              Create, optimize, and debug your Lua scripts with a smarter
              development experience.
            </p>

            <div className="hero-buttons">
              <a href="#workspace" className="primary-button">
                Explore Viemos <ArrowRight size={18} />
              </a>
              <a
                href="https://github.com/ultrasyao/viemos"
                target="_blank"
                rel="noreferrer"
                className="secondary-button"
              >
                <Github size={18} /> View on GitHub
              </a>
            </div>

            <div className="hero-trust">
              <div className="trust-icon"><Check size={14} /></div>
              <span>Free to use</span>
              <span className="trust-divider">·</span>
              <span>Built for GTPS developers</span>
            </div>
          </div>

          <div className="hero-visual">
            <div className="visual-glow" />
            <div className="editor-window">
              <div className="editor-topbar">
                <div className="window-dots">
                  <span /><span /><span />
                </div>
                <div className="editor-filename">
                  <FileCode2 size={14} /> welcome.lua
                </div>
                <div className="editor-status">
                  <span /> Lua
                </div>
              </div>

              <div className="editor-body">
                <div className="editor-sidebar">
                  <div className="sidebar-icon active"><Layers3 size={17} /></div>
                  <div className="sidebar-icon"><FileCode2 size={17} /></div>
                  <div className="sidebar-icon"><Command size={17} /></div>
                </div>

                <div className="code-area">
                  <div className="code-header">
                    <span><span className="live-dot" /> WELCOME.LUA</span>
                    <span className="code-header-right">UTF-8 · LF</span>
                  </div>
                  {codeLines.map((line) => (
                    <div className="code-line" key={line.number}>
                      <span className="line-number">{line.number}</span>
                      <span className={`code-${line.type}`}>
                        {line.content || "\u00a0"}
                      </span>
                    </div>
                  ))}
                  <div className="code-cursor" />
                </div>
              </div>

              <div className="editor-footer">
                <span><span className="live-dot" /> Ready</span>
                <span>Ln 4, Col 1</span>
                <span>Lua</span>
              </div>
            </div>

            <div className="floating-card floating-ai">
              <div className="floating-icon"><Sparkles size={17} /></div>
              <div>
                <strong>AI Assistant</strong>
                <span>Ready to help you code</span>
              </div>
              <span className="ai-online" />
            </div>

            <div className="floating-card floating-status">
              <div className="status-check"><Check size={15} /></div>
              <div>
                <strong>Workspace ready</strong>
                <span>Everything in one place</span>
              </div>
            </div>
          </div>

          <div className="hero-bottom">
            <span>DESIGNED FOR DEVELOPERS</span>
            <div className="hero-bottom-line" />
            <span>POWERED BY CREATIVITY <Sparkles size={13} /></span>
          </div>
        </section>

        <section className="features-section" id="features">
          <div className="section-heading">
            <div className="section-eyebrow">
              <span /> WHAT YOU CAN DO
            </div>
            <h2>
              Everything you need.
              <br />
              <span className="gradient-text">One workspace.</span>
            </h2>
            <p>
              A focused toolkit designed to make GTPS development
              more productive and enjoyable.
            </p>
          </div>

          <div className="features-grid">
            {features.map((feature, index) => {
              const Icon = feature.icon;
              return (
                <article className="feature-card" key={feature.title}>
                  <div className="feature-card-top">
                    <div className="feature-icon"><Icon size={21} /></div>
                    <span className="feature-index">0{index + 1}</span>
                  </div>
                  <span className="feature-tag">{feature.tag}</span>
                  <h3>{feature.title}</h3>
                  <p>{feature.description}</p>
                  <div className="feature-arrow"><ArrowUpRight size={17} /></div>
                </article>
              );
            })}
          </div>
        </section>

        <section className="workflow-section" id="workflow">
          <div className="workflow-copy">
            <div className="section-eyebrow"><span /> A BETTER WORKFLOW</div>
            <h2>
              From idea to
              <br />
              <span className="gradient-text">implementation.</span>
            </h2>
            <p>
              Spend less time dealing with repetitive coding tasks.
              Focus on creating features and building better GTPS experiences.
            </p>
            <a href="#workspace" className="text-link">
              Discover the workspace <ArrowRight size={17} />
            </a>
          </div>

          <div className="workflow-steps">
            <div className="workflow-step">
              <div className="step-number">01</div>
              <div>
                <h3>Describe your idea</h3>
                <p>Tell the AI what you want to build.</p>
              </div>
            </div>
            <div className="step-line" />
            <div className="workflow-step">
              <div className="step-number">02</div>
              <div>
                <h3>Review the code</h3>
                <p>Inspect generated Lua scripts and suggested changes.</p>
              </div>
            </div>
            <div className="step-line" />
            <div className="workflow-step">
              <div className="step-number">03</div>
              <div>
                <h3>Build with confidence</h3>
                <p>Refine your work and keep your projects organized.</p>
              </div>
            </div>
          </div>
        </section>

        <section className="cta-section" id="workspace">
          <div className="cta-glow" />
          <div className="cta-icon"><Bot size={27} /></div>
          <div className="section-eyebrow"><span /> YOUR NEXT IDEA STARTS HERE</div>
          <h2>
            Ready to build
            <br />
            <span className="gradient-text">something better?</span>
          </h2>
          <p>
            Your ideas deserve a better development workspace.
            Welcome to Viemos.
          </p>
          <a href="#features" className="primary-button">
            Explore features <ArrowRight size={18} />
          </a>
          <div className="cta-note"><Moon size={13} /> A workspace made for creators.</div>
        </section>
      </main>

      <footer className="footer">
        <a href="#" className="brand footer-brand">
          <span className="brand-symbol"><Braces size={20} /></span>
          <span>viemos<span className="brand-dot">.</span></span>
        </a>
        <p>Build smarter. Code better.</p>
        <span className="footer-copy">© 2026 Viemos. Made for GTPS creators.</span>
      </footer>
    </div>
  );
}

export default App;

