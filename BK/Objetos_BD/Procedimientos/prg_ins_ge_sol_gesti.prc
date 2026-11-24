CREATE OR REPLACE PROCEDURE IT.PRG_INS_GE_SOL_GESTI
 (RP_GSGES IN OUT GE_SOL_GESTIONES%ROWTYPE
 )
 IS
BEGIN
   if rp_gsges.fecha is null then
      if rp_gsges.cod_estado = 'PVD' Then
         rp_gsges.fecha := to_date(to_char(sysdate,'DDMMYYYY')||pag_gen.fu_obt_sig_segundo(to_char(sysdate, 'HH24:MI:SS')),'DDMMYYYY HH24:MI:SS');
      else
         rp_gsges.fecha := sysdate;--to_date(to_char(pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo),'DDMMYYYY')||to_char(sysdate,'HH24MISS'),'DDMMYYYY HH24MISS');
      End If;
   end if;
   INSERT INTO GE_SOL_GESTIONES(NRO_SOLICITUD,
                                COD_ESTADO,
                                TIPO,
                                FECHA,
                                COD_USUARIO,
                                OBSERVACION)
                         VALUES(rp_gsges.nro_solicitud,
                                rp_gsges.COD_ESTADO,
                                rp_gsges.TIPO,
                                rp_gsges.fecha,
                                rp_gsges.COD_USUARIO,
                                rp_gsges.OBSERVACION);
END;
/

