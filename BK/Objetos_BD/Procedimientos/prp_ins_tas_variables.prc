CREATE OR REPLACE PROCEDURE IT.PRP_INS_TAS_VARIABLES
 (r_cab IN pr_tas_variables%ROWTYPE default null,
 r_det IN pr_tas_variables_det%ROWTYPE default null,
 p_tipo IN CHAR default null
 )
 IS
/* p_tipo ('C' Cabecera/ 'D' Detalle)*/
   v_error varchar2(30);
   --
BEGIN
    --- NLS B.D.
   PRE_CAM_FOR_NUMERICO('.,');
   if p_tipo = 'C' then
      v_error := 'PR_TAS_VARIABLES';
      insert into pr_tas_variables (COD_MODULO,COD_MODALIDAD,COD_SUB_MODALIDAD,
                  COD_MONEDA,NRO_SOLICITUD,COD_PERSONA,MONTO,TOT_PRESTAMO,
                  TOT_DESEMBOLSAR,NRO_CUOTAS,
                  TIP_INTERES,TAS_INTERES,TAS_REFERENCIA,
                  FEC_RENEGOCIACION,COD_PERIODO,SPREAD,NRO_CUENTA,DESCRIPCION,TAS_PISO,
                  TOT_CAPITAL, TOT_INTERES,
                  TOT_INT_ADELANTADO, TOT_INT_ORIGINAL,
                  SC_TOT_INT_ORIGINAL, TOT_CARGO, TOT_VAL_CUOTA,TIP_SPREAD,
                  USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
      VALUES      (R_CAB.COD_MODULO,R_CAB.COD_MODALIDAD,R_CAB.COD_SUB_MODALIDAD,
                  R_CAB.COD_MONEDA,R_CAB.NRO_SOLICITUD,
                  R_CAB.COD_PERSONA,R_CAB.MONTO,R_CAB.TOT_PRESTAMO,
                  R_CAB.TOT_DESEMBOLSAR,R_CAB.NRO_CUOTAS,
                  R_CAB.TIP_INTERES,R_CAB.TAS_INTERES,R_CAB.TAS_REFERENCIA,
                  R_CAB.FEC_RENEGOCIACION,R_CAB.COD_PERIODO,R_CAB.SPREAD,
                  R_CAB.NRO_CUENTA,R_CAB.DESCRIPCION,R_CAB.TAS_PISO,
                  R_CAB.TOT_CAPITAL, R_CAB.TOT_INTERES,
                  R_CAB.TOT_INT_ADELANTADO, R_CAB.TOT_INT_ORIGINAL,
                  R_CAB.SC_TOT_INT_ORIGINAL, R_CAB.TOT_CARGO,
                  R_CAB.TOT_VAL_CUOTA,R_CAB.TIP_SPREAD,
                  USER, SYSDATE,USER,SYSDATE);
   ELSIF p_tipo = 'D' then
      v_error := 'PR_TAS_VARIABLES_DET';
      insert into pr_tas_variables_det (COD_PERIODO,
            NRO_CUOTA,DIA,FEC_VENCIMIENTO,
            MTO_CAPITAL,VAL_INT_ADELANTADO, VAL_INTERES,
            VAL_INT_ORIGINAL,MTO_CARGO,
            TOT_CUOTA, RENEGOCIACION, TAS_REFERENCIA,
            TAS_UTILIZADA, NRO_SOLICITUD,SPREAD,
            USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
      values (R_DET.COD_PERIODO,
            R_DET.NRO_CUOTA,R_DET.DIA,R_DET.FEC_VENCIMIENTO,
            R_DET.MTO_CAPITAL,R_DET.VAL_INT_ADELANTADO,R_DET.VAL_INTERES,
            R_DET.VAL_INT_ORIGINAL ,R_DET.MTO_CARGO,
            R_DET.TOT_CUOTA, R_DET.RENEGOCIACION,R_DET.TAS_REFERENCIA,
            R_DET.TAS_UTILIZADA,R_DET.NRO_SOLICITUD, R_DET.SPREAD,
             USER, SYSDATE,USER,SYSDATE);
   END IF;
exception
  when others then
        raise_application_error(-20000,'PRP_INS_TAS_VARIABLES('||p_tipo||')insertar en '||v_error
                            ||' Usuario '||substr(lower(user),1,6)
                            ||' Nro_solicitud '||nvl(r_cab.nro_solicitud,r_det.nro_solicitud)||'-'||sqlerrm);
END;
/

