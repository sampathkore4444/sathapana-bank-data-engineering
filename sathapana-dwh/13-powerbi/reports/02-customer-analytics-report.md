# Sathapana Bank - Customer Analytics Power BI Report

## Report Overview
**Report Name**: Customer 360 Dashboard
**Data Source**: sathapana_dm_customer.dm schema
**Refresh**: Daily at 6:00 AM

---

## Data Connection

### Connection String
```
Server: [YOUR_SERVER_NAME]
Database: sathapana_dm_customer
```

### Tables to Import
1. `dm.vw_customer_360`
2. `dm.vw_customer_segmentation`
3. `dm.vw_customer_profitability`
4. `dm.vw_customer_lifecycle`
5. `dm.vw_customer_acquisition`
6. `dm.vw_customer_demographics`
7. `dm.vw_top_customers`

---

## Report Pages

### Page 1: Executive Summary

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                 CUSTOMER 360 DASHBOARD                       │
│                 Sathapana Bank                               │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ Total    │ │ Active   │ │ Total    │ │ Total    │      │
│  │ Customers│ │ Customers│ │ Accounts │ │ Balance  │      │
│  │ X,XXX    │ │ X,XXX    │ │ X,XXX    │ │ $XX.XM   │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  Customer by        │ │  Customer Growth (Line)     │   │
│  │  Segment (Pie)      │ │  12 months                  │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  Top Provinces      │ │  Channel Usage (Stacked)    │   │
│  │  (Bar Chart)        │ │                             │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

### Page 2: Customer Segmentation

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                 CUSTOMER SEGMENTATION                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Segment Distribution (Treemap)                     │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  Income Bracket     │ │  Risk Rating Distribution   │   │
│  │  (Histogram)        │ │  (Stacked Bar)              │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Segment Comparison Matrix                         │   │
│  │  (Rows: Segments, Columns: Metrics)                │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

### Page 3: Customer Lifecycle

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                 CUSTOMER LIFECYCLE                           │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ New      │ │ Growing  │ │ Mature   │ │ Veteran  │      │
│  │ (0-3M)   │ │ (3-12M)  │ │ (1-3Y)   │ │ (3Y+)    │      │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  Lifecycle Funnel   │ │  Tenure Distribution        │   │
│  │  (Funnel Chart)     │ │  (Bar Chart)                │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Acquisition Channel Performance (Combo Chart)      │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

### Page 4: Top Customers

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│                 TOP CUSTOMERS                                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Top 20 Customers by Balance (Horizontal Bar)       │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Customer Details Table                             │   │
│  │  (Searchable, Sortable)                             │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐ ┌─────────────────────────────┐   │
│  │                     │ │                             │   │
│  │  Segment of Top     │ │  Geographic Distribution    │   │
│  │  Customers (Pie)    │ │  (Map)                      │   │
│  │                     │ │                             │   │
│  └─────────────────────┘ └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## DAX Measures to Use

Import measures from: `13-powerbi/measures/02-customer-analytics-measures.dax`

Key measures:
- `Total Customers`
- `Active Customers`
- `Total Balance`
- `Total Transactions`
- `Revenue per Customer`
- `KYC Completion Rate`

---

## Filters & Slicers

1. **Date Range**: Calendar picker
2. **Branch**: Dropdown (multi-select)
3. **Customer Segment**: Dropdown
4. **Province**: Dropdown
5. **Risk Rating**: Dropdown
6. **KYC Status**: Dropdown

---

## Drill-Through Pages

### Customer Detail Page
- Triggered by clicking on any customer
- Shows complete customer 360 view
- Account list, transaction history, products held

---

## Bookmarks

1. **Segment View**: Shows segmentation analysis
2. **Geographic View**: Shows map-focused analysis
3. **Top Customers View**: Shows top customer analysis
4. **Compliance View**: Shows KYC/AML focused view

---

## Mobile Layout

Create optimized layout for mobile viewing:
- Simplified KPI cards
- Essential charts only
- Portrait orientation
