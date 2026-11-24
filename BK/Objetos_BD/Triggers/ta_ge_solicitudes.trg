CREATE OR REPLACE TRIGGER IT.TA_GE_SOLICITUDES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_SOLICITUDES
 FOR EACH ROW


DECLARE

    v_fecha ge_sol_gestiones.fecha%type;
    r_gsges ge_sol_gestiones%rowtype;
BEGIN
   if  INSERTING
   or (UPDATING
     and (:new.cod_estado    <> :old.cod_estado
          and :new.cod_estado IN ('NEN','PDE','TIA')))
   then
      r_gsges.nro_solicitud := :new.nro_solicitud;
      r_gsges.cod_estado    := :new.cod_estado;
      r_gsges.tipo          := :new.tipo;
      if r_gsges.cod_estado = 'PVD' Then
         r_gsges.fecha := to_date(to_char(sysdate,'DDMMYYYY')||pag_gen.fu_obt_sig_segundo(to_char(sysdate, 'HH24:MI:SS')),'DDMMYYYY HH24:MI:SS');
      else
         r_gsges.fecha := sysdate;--to_date(to_char(pag_cal.fu_obt_fec_actual(pae_cnf.g_cod_modulo),'DDMMYYYY')||to_char(sysdate,'HH24MISS'),'DDMMYYYY HH24MISS');
      End If;
      if inserting or :new.cod_estado IN ('NEN','PDE','TIA') then
         r_gsges.cod_usuario := user;
      else
         r_gsges.cod_usuario := fug_obt_usu_sol(:new.cod_estado, :new.cod_modulo,
                                                :new.cod_campana, :new.cod_canal,
                                                :new.cod_moneda, :new.monto);
      end if;
      r_gsges.observacion   := :new.observacion;
      prg_ins_ge_sol_gesti(r_gsges);
   end if;
END;
/

