-- CreateTable
CREATE TABLE "Rating" (
    "id" TEXT NOT NULL,
    "tripId" TEXT NOT NULL,
    "ratedBy" TEXT NOT NULL,
    "ratedUserId" TEXT NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Rating_pkey" PRIMARY KEY ("id")
);
