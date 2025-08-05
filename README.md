# Blockchain-Based Public Inventory and Supply Chain Management

A comprehensive Clarity smart contract system for managing government supply chains, inventory tracking, vendor performance, emergency stockpiles, and asset lifecycle management.

## System Overview

This system consists of five interconnected smart contracts that provide transparency, accountability, and efficiency in public sector supply chain operations:

### 1. Government Supply Procurement Contract (`procurement.clar`)
- Manages purchasing of office supplies, equipment, and materials
- Handles purchase orders, approvals, and budget tracking
- Ensures compliance with procurement regulations

### 2. Inventory Tracking and Distribution Contract (`inventory.clar`)
- Monitors stock levels across departments
- Coordinates distribution to government departments
- Tracks item movements and consumption patterns

### 3. Vendor Performance Evaluation Contract (`vendor-performance.clar`)
- Tracks supplier reliability, quality metrics, and delivery performance
- Maintains vendor ratings and compliance scores
- Supports vendor selection and contract renewal decisions

### 4. Emergency Supply Stockpile Management Contract (`emergency-supplies.clar`)
- Maintains reserves of medical supplies, food, and disaster response equipment
- Monitors expiration dates and rotation schedules
- Ensures readiness for emergency response

### 5. Asset Lifecycle Management Contract (`asset-lifecycle.clar`)
- Tracks government property from purchase through disposal
- Manages depreciation, maintenance schedules, and transfers
- Ensures proper asset accountability and disposal procedures

## Key Features

- **Transparency**: All transactions and decisions recorded on blockchain
- **Accountability**: Immutable audit trail for all supply chain activities
- **Efficiency**: Automated workflows and real-time inventory tracking
- **Compliance**: Built-in regulatory compliance checks
- **Emergency Readiness**: Dedicated emergency supply management

## Contract Interactions

The contracts work together to provide a complete supply chain solution:
- Procurement creates inventory items
- Inventory tracks distribution and consumption
- Vendor performance influences procurement decisions
- Emergency supplies maintain critical reserves
- Asset lifecycle manages the complete property lifecycle

## Getting Started

1. Deploy contracts in order: procurement, inventory, vendor-performance, emergency-supplies, asset-lifecycle
2. Initialize system parameters and admin roles
3. Register vendors and departments
4. Begin normal operations

## Testing

Run the test suite with:
\`\`\`
npm test
\`\`\`

## Security Considerations

- Role-based access control for all operations
- Input validation and bounds checking
- Emergency pause functionality for critical situations
- Audit logging for all state changes
