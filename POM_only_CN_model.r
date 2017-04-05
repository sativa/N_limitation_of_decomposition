#Building a linked C-N model examining N fertilization effects on POM and MAOM formation. 
###FIXED CUE AND NUE###
###Colin Averill modifying April 1, 2017

###ASSUMPTIONS###
# C:N stoichiometry of MAOM, POM, and microbial biomass are fixed
# microbes take up organic N (from decomposition of POM) before taking up inorganic N
# microbes aim to have the C:N ratio of uptake match their biomass stoichiometry
# when microbes are C-limited, they mineralize excess N
# when microbes are N-limited, they immobilize sufficient inorganic N to match stoichiometric demand
# if there is not enough inorganic N to match demand, then they respire excess C such that the C:N ratio of uptake matches    biomass stoichiometry

#clear R environment.
rm(list=ls())

#parameters: C cycling
#WARNING. Most parameters can change the position of C vs. N limitation ~ input CN.
#If you change things, make sure you are always checking where C vs N limitation is. 
I    <- 1.0      #C input rate                           (mg time-1)
CUE  <- 0.3      #carbon use efficiency                  (unitless)
NUE  <- 1 		   #N use efficiency					             (unitless)
v1   <- .4       #biomass-specific decay multiplier      (mg time-1)
v2   <- 1        #Vmax of sorption                       (mg time-1)
k1   <- 200      #half saturation of decomp              (mg)
k2   <- 10       #half saturation of sorption            (mg)
k3   <- 0.001    #half saturation of inorganic N uptake  (mg)
h1   <- 0.01     #biomass turnover rate                  (1/time)
h2   <- 0.002    #C-specific desorption rate             (1/time)
h3   <- 0.001    #fraction of POM that potentially sorbs (1/time)
h4   <- 0.9      #inorganic N loss rate
h5   <- 0.01     #exogenous losses of POM                (1/time)

#parameters: N cycling
IN <- 20 #C:N ratio of inputs (constant)
CN <- 50 #C:N ratio of initial particulate organic matter (will change)
MN <- 25 #C:N ratio of initial mineral-associated organic matter (will change)
BN <- 7 #C:N ratio of the microbial biomass (constant)

#initial pool sizes
C <- 100      #C pool in POM            (mg / g)
#M <-  20      #C pool in MAOM           (mg / g)
B <- C*0.1    #microbial biomass C 			(mg / g)
R <- 0        # respired C				    	(mg / g)
N1 <- C/CN    #initial N pool in POM		(mg / g)
#N2 <- M/MN	  #N pool in MAOM 			  	(mg / g)
N3 <- B/BN    #microbial biomass N			(mg / g)
N4 <- 0.001	  #inorganic N pool size 		(mg / g)

#number of days to step the dynamic simulation through time.
t <- 1500

#choose outputs you want to follow. 
outputs <- c('B','C','R','N1','N3','N4')
out <- matrix(rep(0,t*length(outputs)),nrow=t,dimnames=list(NULL,outputs))


for(i in 1:t){
  #C fluxes
  DEATH.C      <- h1*B^1.5
  DECOMP.C     <- v1*B*C / (k1 + C)
  exo.loss.C   <- h5*C
  #POM2MOM.C    <- h3*C
  #SORPTION.C   <- v2*(POM2MOM.C+DEATH.C) / (k2 + POM2MOM.C+DEATH.C)
  #SORPTION.B.C <- (DEATH.C  /(POM2MOM.C+DEATH.C))*SORPTION.C
  #SORPTION.P.C <- (POM2MOM.C/(POM2MOM.C+DEATH.C))*SORPTION.C
  #DESORPTION.C <- h2*M
  
  #N fluxes
  DEATH.N      <- DEATH.C / BN
  DECOMP.N     <- DECOMP.C/ (C / N1)
  exo.loss.N   <- exo.loss.C / (C/N1)
  #POM2MOM.N    <- POM2MOM.C/CN
  #SORPTION.N   <- v2*(POM2MOM.N+DEATH.N) / (k2 + POM2MOM.N+DEATH.N)
  #SORPTION.B.N <- (DEATH.N  /(POM2MOM.N+DEATH.N))*SORPTION.N
  #SORPTION.P.N <- (POM2MOM.N/(POM2MOM.N+DEATH.N))*SORPTION.N
  #DESORPTION.N <- DESORPTION.C/MN
  
  #MINERALIZATION-IMMOBILIZATION.
  #N uptake minus demand. If in excess, positive. If limited, negative.
  mineralization.immobilization <- (DECOMP.N) - (CUE * DECOMP.C) / BN
  if(mineralization.immobilization  > 0) {
    #if in excess (+ value), mineralize. 
    mineralization <- mineralization.immobilization
    immobilization = 0
  }
  if(mineralization.immobilization <= 0) {
    #if in debt (- value), immobilize, w/ non-linear uptake kinetics.
    mineralization = 0
    immobilization.potential <- ((N4 / (k3 + N4)) * N4) * NUE
    immobilization <- immobilization.potential
    #however, don't take up more N than you need.
    if(immobilization > abs(mineralization.immobilization)){
      immobilization = abs(mineralization.immobilization)
    }
  }
  #leaching/plant uptake happens on post-mineralization/immobilization inorganic N pool.
  INORG.N.LOSS <- h4*(N4 + mineralization - immobilization)
  
  #OVERFLOW RESPIRATION
  #excess C uptake must go somewhere because mass balance.
  if(mineralization.immobilization > 0){
    overflow.R = 0
  }
  if(mineralization.immobilization <= 0){  
    overflow.R <- DECOMP.C*CUE - (DECOMP.N + immobilization)*BN
  }
  
  #ODEs
  dBdt <- (CUE * DECOMP.C) - DEATH.C - overflow.R
  dCdt <- I + DEATH.C - DECOMP.C - exo.loss.C
  #dMdt <- SORPTION.C - DESORPTION.C
  dRdt <- (1-CUE)*DECOMP.C
  
  dN1dt <- (I/IN) + DEATH.N - DECOMP.N - exo.loss.N
  #dN2dt <- SORPTION.N - DESORPTION.N
  dN3dt <- DECOMP.N*NUE + immobilization - mineralization - DEATH.N
  dN4dt <- DECOMP.N*(1-NUE) + mineralization - immobilization - INORG.N.LOSS
  
  #update pools
  B <- B + dBdt
  C  <- C + dCdt
  #M  <- M + dMdt
  R  <-  dRdt
  N1 <- N1 + dN1dt
  #N2 <- N2 + dN2dt
  N3 <- N3 + dN3dt
  N4 <- N4 + dN4dt
  
  #save outputs
  out[i,] <- c(B,C,R,N1,N3,N4)
}

par(mfrow=c(3,3))
plot(out[,1], ylab="microbial biomass C")
plot(out[,2], ylab="POM C")
#plot(out[,3], ylab= "MAOM C")
plot(out[,3], ylab="respiration")
plot(out[,5], ylab="POM N")
#plot(out[,6], ylab= "MAOM N")
plot(out[,5], ylab="microbial biomass N")
plot(out[,6], ylab="inorganic N")
#check stoichiometry of pools
plot(out[,1]/out[,5], cex = 0.1, col='blue' , ylim = c(0,40))
par(new=T)
plot(out[,2]/out[,4], cex = 0.1, col='green', ylim = c(0,40))
#par(new=T)
#plot(out[,3]/out[,6], cex = 0.1, col='red'  , ylim = c(0,40))
C;B;C+B