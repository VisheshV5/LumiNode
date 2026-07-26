"""LumiNode - Marketing hero for the landing route ("/").

Starts dormant - a dark "black box" showing only a dim logo and a single
Luminize button. Pressing it blooms bright light out from the button, the
logo ignites, and the full lit hero reveals with the original content.
"""

import from "@jac/runtime" { useNavigate }
import from "./components/magicui/particles" { Particles }
import from "./components/magicui/sparkles-text" { SparklesText }
import from "./components/magicui/shimmer-button" { ShimmerButton }
import from "./components/magicui/blur-fade" { BlurFade }

def:pub LandingHero() -> JsxElement {
    has luminized: bool = False;

    nav = useNavigate();

    def luminize(e: MouseEvent) { luminized = True; }
    def goStart(e: MouseEvent) { nav("/signup"); }
    def goSample(e: MouseEvent) { nav("/signup?sample=1"); }

    return <div className={"lumi-landing" + (" lumi-lit" if luminized else "")}>
        <div className="lumi-hero-glow"/>
        {if luminized {
            <div className="lumi-flash"/>
        }}
        {if luminized {
            <Particles className="absolute inset-0" quantity={70} color="#F0C850" staticity={40} size={0.6} ease={40}/>
        }}

        <div className="lumi-landing-inner">
            {if not luminized {
                <div className="lumi-dormant">
                    <button className="lumi-luminize-btn" onClick={luminize}>Luminize</button>
                    <p className="lumi-dormant-hint">Your score is in the dark. Press to light it up.</p>
                </div>
            }}

            {if luminized {
                <div className="lumi-hero-content">
                    <BlurFade delay={0.0} inView={False}>
                        <img className="lumi-logo-img" src="/assets/luminode_logo.png" alt="LumiNode"/>
                    </BlurFade>
                    <BlurFade delay={0.15} inView={False}>
                        <h1 className="lumi-hero-title">
                            Your credit score is a black box.
                        </h1>
                    </BlurFade>
                    <BlurFade delay={0.3} inView={False}>
                        <SparklesText
                            className="lumi-hero-title lumi-hero-title-glow"
                            colors={{"first": "#F0C850", "second": "#F5F5F7"}}
                            sparklesCount={8}
                        >
                            LumiNode lights up every node.
                        </SparklesText>
                    </BlurFade>
                    <BlurFade delay={0.45} inView={False}>
                        <p className="lumi-hero-subtitle">
                            See what's really driving your score. Find the fastest path to your target.
                            Just text us your questions.
                        </p>
                    </BlurFade>
                    <BlurFade delay={0.6} inView={False}>
                        <ShimmerButton
                            background="#F0C850"
                            shimmerColor="#0A0A0F"
                            className="text-black font-bold text-lg gap-2 font-[Space_Grotesk]"
                            onClick={goStart}
                        >
                            Light Up My Score <span className="lumi-arrow">→</span>
                        </ShimmerButton>
                        <button className="lumi-link-btn" onClick={goSample}>
                            Try a sample profile instead
                        </button>
                    </BlurFade>
                    <BlurFade delay={0.75} inView={False}>
                        <p className="lumi-hero-tagline">Built for people who need it most.</p>
                    </BlurFade>
                </div>
            }}
        </div>
    </div>;
}
