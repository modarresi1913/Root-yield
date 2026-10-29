// SPDX-License-Identifier: MIT
// MGP Ponder indexer (Book III per spec section 5).
import { ponder } from "@/generated";
import { createSchema } from "@ponder/core";

export default createSchema({
  Donation: {
    id: p.string.id(),
    agent: p.string(),
    amount: p.bigint(),
    generationId: p.bigint(),
    blockTimestamp: p.bigint(),
    txHash: p.string(),
  },
  Match: {
    id: p.string.id(),
    donationId: p.string(),
    amount: p.bigint(),
    blockTimestamp: p.bigint(),
    txHash: p.string(),
  },
  Generation: {
    id: p.string.id(),
    generationId: p.bigint(),
    timestamp: p.bigint(),
  },
  Voucher: {
    id: p.string.id(),
    child: p.string(),
    parentDid: p.string(),
    amount: p.bigint(),
    issuedAt: p.bigint(),
    redeemableAt: p.bigint(),
    redeemed: p.boolean(),
    txHash: p.string(),
  },
  Redemption: {
    id: p.string.id(),
    voucherId: p.string(),
    redeemer: p.string(),
    blockTimestamp: p.bigint(),
    txHash: p.string(),
  },
  Repayment: {
    id: p.string.id(),
    child: p.string(),
    amount: p.bigint(),
    blockTimestamp: p.bigint(),
    txHash: p.string(),
  },
});

ponder.on("LineagePool:Donation", async ({ event, context }) => {
  await context.db.Donation.insert({
    id: event.log.id,
    agent: event.args.agent,
    amount: event.args.amount,
    generationId: event.args.generationId,
    blockTimestamp: BigInt(event.block.timestamp),
    txHash: event.log.transactionHash,
  });
});

ponder.on("MatchingEngine:Match", async ({ event, context }) => {
  await context.db.Match.insert({
    id: event.log.id,
    donationId: event.args.donationId,
    amount: event.args.amount,
    blockTimestamp: BigInt(event.block.timestamp),
    txHash: event.log.transactionHash,
  });
});

ponder.on("LineagePool:GenerationBorn", async ({ event, context }) => {
  await context.db.Generation.insert({
    id: event.log.id,
    generationId: event.args.generationId,
    timestamp: BigInt(event.args.timestamp),
  });
});

ponder.on("VoucherRedeem:VoucherIssued", async ({ event, context }) => {
  await context.db.Voucher.insert({
    id: event.args.voucherId,
    child: event.args.child,
    parentDid: "",
    amount: event.args.amount,
    issuedAt: BigInt(event.block.timestamp),
    redeemableAt: BigInt(event.block.timestamp) + 7n * 24n * 3600n,
    redeemed: false,
    txHash: event.log.transactionHash,
  });
});

ponder.on("VoucherRedeem:Redeemed", async ({ event, context }) => {
  await context.db.Voucher.update({ id: event.args.voucherId, redeemed: true });
  await context.db.Redemption.insert({
    id: event.log.id,
    voucherId: event.args.voucherId,
    redeemer: event.args.redeemer,
    blockTimestamp: BigInt(event.block.timestamp),
    txHash: event.log.transactionHash,
  });
});

ponder.on("VoucherRedeem:RepaymentPaid", async ({ event, context }) => {
  await context.db.Repayment.insert({
    id: event.log.id,
    child: event.args.child,
    amount: event.args.amount,
    blockTimestamp: BigInt(event.block.timestamp),
    txHash: event.log.transactionHash,
  });
});
