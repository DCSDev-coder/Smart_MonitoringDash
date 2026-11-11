import React, { useState, useEffect } from 'react';

interface AnimatedDcsLogoProps {
  className?: string;
  autoplay?: boolean;
}

export const AnimatedDcsLogo: React.FC<AnimatedDcsLogoProps> = ({
  className = 'h-10 sm:h-11',
  autoplay = true,
}) => {
  const [animating, setAnimating] = useState(false);
  const [isRevealed, setIsRevealed] = useState(false);

  const playAnimation = () => {
    setIsRevealed(false);
    setAnimating(true);
    // Allow start state to register before animating to target
    setTimeout(() => {
      setIsRevealed(true);
    }, 60);
  };

  useEffect(() => {
    if (autoplay) {
      // Subtle delay on mount for dramatic entrance
      const timer = setTimeout(() => {
        playAnimation();
      }, 120);
      return () => clearTimeout(timer);
    } else {
      setIsRevealed(true);
    }
  }, [autoplay]);

  return (
    <div
      onClick={playAnimation}
      onMouseEnter={() => {
        if (!animating) playAnimation();
      }}
      className={`relative inline-block aspect-[2526/1170] cursor-pointer group select-none drop-shadow-sm transition-transform hover:scale-105 active:scale-95 ${className}`}
      title="DCS • Data Center Specialists (Click to replay logo animation)"
    >
      {/* 1. Subtitle: DATA CENTER SPECIALISTS (Fades in smoothly) */}
      <img
        src="/DATA_CENTER_SPECIALISTS.png"
        alt=""
        className="absolute inset-0 w-full h-full object-contain pointer-events-none transition-all duration-700 ease-out"
        style={{
          opacity: isRevealed ? 1 : 0,
          transform: isRevealed ? 'translateY(0)' : 'translateY(2px)',
          transitionDelay: isRevealed ? '350ms' : '0ms',
        }}
      />

      {/* 2. Static 'D' Letter */}
      <img
        src="/D.png"
        alt="D"
        className="absolute inset-0 w-full h-full object-contain pointer-events-none"
      />

      {/* 3. Static 'S' Letter */}
      <img
        src="/S.png"
        alt="S"
        className="absolute inset-0 w-full h-full object-contain pointer-events-none"
      />

      {/* 4. Registered Trademark '®' */}
      <img
        src="/R-01 (1).png"
        alt="®"
        className="absolute inset-0 w-full h-full object-contain pointer-events-none"
      />

      {/* 5. The Spinning 'C' and Green Line group (Rotates from UP -90deg to RIGHT 0deg like Flutter app) */}
      <div
        onTransitionEnd={() => setAnimating(false)}
        className="absolute inset-0 w-full h-full pointer-events-none origin-center"
        style={{
          transform: isRevealed
            ? 'translate(1.2%, 1.67%) rotate(0deg)'
            : 'translate(4%, -6.67%) rotate(-90deg)',
          transition: 'transform 850ms cubic-bezier(0.16, 1, 0.3, 1)',
        }}
      >
        <img
          src="/C.png"
          alt="C"
          className="absolute inset-0 w-full h-full object-contain"
        />
        <img
          src="/GREEN_LINE.png"
          alt=""
          className="absolute inset-0 w-full h-full object-contain"
        />
      </div>
    </div>
  );
};
