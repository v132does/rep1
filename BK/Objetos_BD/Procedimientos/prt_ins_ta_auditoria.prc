CREATE OR REPLACE PROCEDURE IT.PRT_INS_TA_AUDITORIA
 (RP_TAUDI IN TA_AUDITORIAS%ROWTYPE
 )
 IS

/* Obtener datos de parametros */
PROCEDURE PRG_OBT_GE_PARAMETRO
 (P_PARAMETRO IN GE_PARAMETROS.PARAMETRO%TYPE
 ,RP_GPARAM IN OUT GE_PARAMETROS%ROWTYPE
 );

/* Obtener datos de parametros */
PROCEDURE PRG_OBT_GE_PARAMETRO
 (P_PARAMETRO IN GE_PARAMETROS.PARAMETRO%TYPE
 ,RP_GPARAM IN OUT GE_PARAMETROS%ROWTYPE
 )
 IS
BEGIN
   select *
   into rp_gparam
   from ge_parametros
   where parametro = p_parametro;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Parámetro '||p_parametro||' no registrado');
END;
BEGIN
   if rp_taudi.detalle is not null then
      insert into ta_auditorias
      (tabla,
       clave,
       usuario,
       fec_sistema,
       fec_calendario,
       tip_novedad,
       origen,
       terminal,
       detalle)
      values
      (rp_taudi.tabla,
       rp_taudi.clave,
       USER,
       SYSDATE,
       rp_taudi.fec_calendario,
       rp_taudi.tip_novedad,
       PAE_CNF.G_PROGRAMA,
       PAE_CNF.FU_OBT_TERMINAL,
       rp_taudi.detalle);
   end if;
END;
/

