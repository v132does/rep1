CREATE OR REPLACE PROCEDURE IT.PRA_CAL_DEV_CERTIF
IS
BEGIN
--dbms_output.put_line('Entro al procedimiento');
      PAA_DEV.G_LUGAR     := 'Obtener Moneda Local';
      PAA_DEV.G_MON_LOCAL := PAG_GEN.FU_OBT_MON_LOCAL;
   --
      PAA_DEV.G_LUGAR := 'Obtiene cambio de GE_CALENDRIOS';
      PAG_CAL.PR_OBT_DAT_CALENDAR(PAA_DEV.G_COD_MODULO);
   --
   --
      PAA_DEV.G_FEC_HOY       := PAG_CAL.G_FEC_ACTUAL;
      PAA_DEV.G_ULT_MES_HABIL := PAG_CAL.G_ULT_DIA_MES_HABIL;
      PAA_DEV.G_ULT_DIA_MES   := PAG_CAL.G_ULT_DIA_MES;
      PAA_DEV.G_FEC_PROXIMA   := PAG_CAL.G_FEC_PROXIMA;
      PAA_DEV.G_FEC_ANTERIOR  := PAG_CAL.G_FEC_ANTERIOR;
      PAA_DEV.G_PRI_DIA_MES   := PAG_CAL.G_PRI_DIA_MES;
      PAA_DEV.G_PRI_MES_HABIL := PAG_CAL.G_PRI_DIA_MES_HABIL;
   --
      PAA_DEV.G_LUGAR := 'Devengamiento de Certificados';
      PAA_DEV.PR_DEV_AH_CTA_CERTIF;
   --
      PAA_DEV.G_LUGAR := 'Devengamiento de Plazos Fijos';
      PAA_DEV.PR_DEV_AH_CTA_PLAZOS;
   --
      PAA_DEV.G_LUGAR := 'Devengamiento de Minusvalia - Plusvalia';
      PAA_DEV.PR_DEV_BON_SUBORDINADOS;      
   --
   EXCEPTION
      WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20001,SQLERRM||' '||PAA_DEV.G_LUGAR);
END;
/

