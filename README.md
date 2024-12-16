# VoteFuel: Decentralized Crowdfunding Platform on Stacks

## Overview

VoteFuel is a decentralized crowdfunding platform built on the Stacks blockchain using Clarity smart contracts. The platform enables project creators to raise funds and manage milestone-based project funding with transparent governance and campaign completion tracking.

## Key Features

- Create crowdfunding projects with detailed milestones
- Contribute to projects using STX tokens
- Milestone-based funding release
- Transparent project tracking and governance
- Campaign completion management
- Automated project status tracking
- Refund mechanism for failed projects

## Smart Contract Functions

### `create-project`
- Create a new crowdfunding project
- Define project title, description, target amount, and milestones
- Validates total milestone amounts
- Initializes project completion status

### `contribute`
- Allow users to contribute STX to a project
- Tracks individual and total contributions
- Ensures project is active and within deadline

### `approve-milestone`
- Project creators can approve project milestones
- Ensures only the project creator can approve
- Prevents duplicate milestone approvals

### `withdraw-milestone-funds`
- Withdraw funds for approved milestones
- Validates milestone approval and creator
- Automatically completes project when all milestones are approved and funds withdrawn

### `complete-project`
- Mark a project as complete
- Requires all milestones to be approved
- Only callable by project creator
- Automatically triggered after final milestone withdrawal

### `request-refund`
- Allow contributors to request refunds for failed projects
- Validates refund eligibility
- Prevents duplicate refunds

### `close-failed-project`
- Close projects that didn't meet funding goals
- Enable refund mechanism for contributors
- Updates project status appropriately

## Error Codes

- `ERR-UNAUTHORIZED (u100)`: Unauthorized access attempt
- `ERR-INSUFFICIENT-FUNDS (u101)`: Funding requirements not met
- `ERR-PROJECT-NOT-FOUND (u102)`: Project does not exist
- `ERR-CAMPAIGN-CLOSED (u103)`: Project campaign is closed
- `ERR-MILESTONE-ALREADY-APPROVED (u104)`: Milestone already approved
- `ERR-INVALID-MILESTONE-INDEX (u105)`: Invalid milestone index
- `ERR-NO-REFUND-ELIGIBLE (u106)`: Not eligible for refund
- `ERR-ALREADY-REFUNDED (u107)`: Already received refund
- `ERR-PROJECT-SUCCESSFUL (u108)`: Project is successful
- `ERR-INVALID-INPUT (u109)`: Invalid input parameters
- `ERR-NOT-ALL-MILESTONES-COMPLETE (u110)`: Not all milestones are complete

## Project States

Projects can be in the following states:
1. **Active**: Accepting contributions
2. **Failed**: Didn't meet funding goal
3. **Complete**: All milestones approved and funds withdrawn
4. **Closed**: No longer active (either failed or complete)

## Development Setup

### Prerequisites
- Stacks development environment
- Clarinet for local development and testing
- Basic understanding of Clarity smart contract development

### Local Development
1. Clone the repository
2. Install Clarinet

## Security Considerations

- Implement additional access controls
- Conduct comprehensive smart contract audits
- Add emergency stop mechanisms
- Implement comprehensive error handling
- Validate milestone completion requirements
- Ensure proper fund distribution
- Protect against completion state manipulation

## Best Practices

- Always verify project status before interactions
- Monitor milestone approvals and completion status
- Keep track of contribution records
- Verify refund eligibility before requesting
- Follow recommended security patterns

## Contribution Guidelines

1. Fork the repository
2. Create a feature branch
3. Submit pull requests
4. Follow Clarity best practices
5. Include tests for new features
6. Update documentation appropriately

