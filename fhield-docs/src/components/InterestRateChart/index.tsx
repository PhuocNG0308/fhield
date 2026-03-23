import React, { useMemo } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer, ReferenceLine,
} from 'recharts';
import { useColorMode } from '@docusaurus/theme-common';

interface RateParams {
  baseRate: number;
  optimalUtil: number;
  slope1: number;
  slope2: number;
  reserveFactor: number;
  label?: string;
}

const DEFAULT_PARAMS: RateParams = {
  baseRate: 2, optimalUtil: 80, slope1: 4, slope2: 50, reserveFactor: 10,
};

function calcRates(u: number, p: RateParams) {
  const { baseRate, optimalUtil, slope1, slope2, reserveFactor } = p;
  let borrowRate: number;
  if (u <= optimalUtil) {
    borrowRate = baseRate + (u / optimalUtil) * slope1;
  } else {
    borrowRate = baseRate + slope1 + ((u - optimalUtil) / (100 - optimalUtil)) * slope2;
  }
  const supplyRate = (borrowRate * (u / 100) * (1 - reserveFactor / 100));
  return { borrowRate: +borrowRate.toFixed(2), supplyRate: +supplyRate.toFixed(2) };
}

function generateData(params: RateParams) {
  const data = [];
  for (let u = 0; u <= 100; u += 1) {
    const { borrowRate, supplyRate } = calcRates(u, params);
    data.push({ utilization: u, borrowRate, supplyRate });
  }
  return data;
}

const palette = {
  dark: {
    bg: 'transparent',
    grid: 'rgba(255,255,255,0.06)',
    text: 'rgba(255,255,255,0.55)',
    borrow: '#0AD9DC',
    supply: '#4fe9eb',
    ref: 'rgba(255,255,255,0.15)',
    tooltipBg: '#0b222f',
    tooltipBorder: 'rgba(59,73,73,0.15)',
  },
  light: {
    bg: 'transparent',
    grid: 'rgba(0,0,0,0.06)',
    text: '#5a5a5a',
    borrow: '#08b8bb',
    supply: '#07979a',
    ref: 'rgba(0,0,0,0.1)',
    tooltipBg: '#ffffff',
    tooltipBorder: 'rgba(120,120,120,0.1)',
  },
};

export default function InterestRateChart({
  configs,
}: {
  configs?: RateParams[];
}) {
  const { colorMode } = useColorMode();
  const c = palette[colorMode] || palette.dark;
  const paramSets = configs?.length ? configs : [DEFAULT_PARAMS];

  const charts = paramSets.map((params, idx) => {
    const data = useMemo(() => generateData(params), [params]);
    const label = params.label || (paramSets.length > 1 ? `Strategy ${idx + 1}` : '');

    return (
      <div key={idx} style={{ marginBottom: paramSets.length > 1 ? '2rem' : 0 }}>
        {label && (
          <div style={{
            fontFamily: "'Space Grotesk', sans-serif",
            fontWeight: 600,
            fontSize: '1rem',
            marginBottom: '0.75rem',
            color: colorMode === 'dark' ? '#fff' : '#1a1a2e',
          }}>
            {label}
          </div>
        )}
        <ResponsiveContainer width="100%" height={400}>
          <LineChart data={data} margin={{ top: 30, right: 30, bottom: 10, left: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke={c.grid} />
            <XAxis
              dataKey="utilization"
              tick={{ fill: c.text, fontSize: 12 }}
              tickFormatter={(v) => `${v}%`}
              label={{ value: 'Utilization', position: 'insideBottomRight', offset: -5, fill: c.text, fontSize: 12 }}
            />
            <YAxis
              tick={{ fill: c.text, fontSize: 12 }}
              tickFormatter={(v) => `${v}%`}
              label={{ value: 'Rate (%)', angle: -90, position: 'insideLeft', fill: c.text, fontSize: 12 }}
            />
            <Tooltip
              contentStyle={{
                background: c.tooltipBg,
                border: `1px solid ${c.tooltipBorder}`,
                borderRadius: '0.375rem',
                fontSize: '0.85rem',
              }}
              labelFormatter={(v) => `Utilization: ${v}%`}
              formatter={(value: number, name: string) => [`${value}%`, name === 'borrowRate' ? 'Borrow Rate' : 'Supply Rate']}
            />
            <Legend
              formatter={(value) => value === 'borrowRate' ? 'Borrow Rate' : 'Supply Rate'}
              wrapperStyle={{ fontSize: '0.85rem' }}
            />
            <ReferenceLine
              x={params.optimalUtil}
              stroke={c.ref}
              strokeDasharray="5 5"
              label={{ value: `${params.optimalUtil}% optimal`, fill: c.text, fontSize: 11, position: 'top' }}
            />
            <Line
              type="monotone"
              dataKey="borrowRate"
              stroke={c.borrow}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4, fill: c.borrow }}
            />
            <Line
              type="monotone"
              dataKey="supplyRate"
              stroke={c.supply}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4, fill: c.supply }}
              strokeDasharray="5 5"
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    );
  });

  return <div>{charts}</div>;
}
