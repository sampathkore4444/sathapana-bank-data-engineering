# Sathapana Bank - Credit Risk Power BI Report

## Report Overview
**Report Name**: Credit Risk Dashboard
**Data Source**: sathapana_dm_credit.dm schema
**Refresh**: Daily at 6:00 AM

---

## Data Connection

### Connection String
```
Server: [YOUR_SERVER_NAME]
Database: sathapana_dm_credit
```

### Tables to Import
1. `dm.vw_credit_risk_summary`
2. `dm.vw_npl_trend`
3. `dm.vw_branch_risk_ranking`
4. `dm.vw_loan_portfolio`
5. `dm.vw_provisioning_summary`
6. `dm.vw_collateral_analysis`

---

## Report Pages

### Page 1: Executive Summary

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                    CREDIT RISK DASHBOARD                     │
│                    Sathapana Bank                            │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Total    │ │ NPL      │ │ NPL      │ │ Provisions│      │
│  │ Outstanding│ │ Ratio   │ │ Amount   │ │ Coverage │      │
│  │ $XX.XM   │ │ X.XX%    │ │ $X.XM    │ │ XX%      │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  NPL Trend (Line)   │ │  Risk Classification (Pie) │   │
│  │  12 months          │ │                             │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  DPD Distribution   │ │  Branch Ranking (Table)     │   │
│  │  (Stacked Bar)      │ │  Top 10 by NPL Ratio        │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Visuals**:
1. **KPI Cards**: Total Outstanding, NPL Ratio, NPL Amount, Provision Coverage
2. **NPL Trend**: Line chart showing NPL ratio over 12 months
3. **Risk Classification**: Pie chart of loan distribution by risk class
4. **DPD Distribution**: Stacked bar chart by Days Past Due buckets
5. **Branch Ranking**: Table with top 10 branches by NPL ratio

---

### Page 2: Portfolio Analysis

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                    PORTFOLIO ANALYSIS                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Portfolio by Product Category (Treemap)            │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  Maturity Profile   │ │  Geographic Distribution    │   │
│  │  (Stacked Column)   │ │  (Map)                      │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Loan Performance by Branch (Matrix)                │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Visuals**:
1. **Product Treemap**: Portfolio breakdown by product category
2. **Maturity Profile**: Bar chart by maturity buckets (0-3M, 3-6M, etc.)
3. **Geographic Map**: Branch locations with NPL ratio intensity
4. **Branch Matrix**: Detailed branch performance table

---

### Page 3: Provisioning & Collateral

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                 PROVISIONING & COLLATERAL                    │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Total    │ │ Required │ │ Provision│ │ Gap      │      │
│  │ Provisions│ │ Provision│ │ Coverage │ │ Amount   │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  Provision by Risk  │ │  Collateral Coverage        │   │
│  │  (Waterfall)        │ │  (Scatter Plot)             │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Collateral Type Distribution (Donut)               │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## DAX Measures to Use

Import measures from: `13-powerbi/measures/01-credit-risk-measures.dax`

Key measures:
- `Total Outstanding`
- `NPL Ratio`
- `NPL Amount`
- `Provision Coverage`
- `DPD 1-30`, `DPD 31-60`, `DPD 61-90`, `DPD 90+`
- `Standard Loans`, `Special Mention Loans`, etc.

---

## Filters & Slicers

1. **Date Range**: Calendar picker
2. **Branch**: Dropdown (multi-select)
3. **Product Category**: Dropdown
4. **Risk Classification**: Dropdown
5. **Region**: Dropdown

---

## Conditional Formatting

### NPL Ratio Card
- Green: ≤ 2%
- Yellow: 2-5%
- Orange: 5-10%
- Red: > 10%

### Branch Table
- Color gradient on NPL Ratio column
- Red highlight for branches with NPL > 5%

---

## Export Options

- PDF export for management reports
- Excel export for detailed analysis
- PowerPoint for presentations
