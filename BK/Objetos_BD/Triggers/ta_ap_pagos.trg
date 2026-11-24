CREATE OR REPLACE TRIGGER IT.TA_AP_PAGOS
 AFTER DELETE OR INSERT OR UPDATE
 ON AP_PAGOS
 FOR EACH ROW


DECLARE

/* Actualiza requerimientos */
PROCEDURE LP_ACT_REQUERIMIENTO
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 ,P_MTO_EJECUTADO IN AP_REQUERIMIENTOS.MTO_EJECUTADO%TYPE
 );

/* Actualiza requerimientos */
PROCEDURE LP_ACT_REQUERIMIENTO
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 ,P_MTO_EJECUTADO IN AP_REQUERIMIENTOS.MTO_EJECUTADO%TYPE
 )
 IS
Begin
--Actualiza el monto ejecutado en Requerimientos
   Update ap_requerimientos
   set mto_ejecutado = nvl(mto_ejecutado,0) + nvl(p_mto_ejecutado,0)
   where cod_requerimiento = p_cod_requerimiento;

   exception
      when others then
         raise_application_error(-20000,'Act. Requerimientos ' || to_char(p_mto_ejecutado)
         || ' - ' || 'Ver Detalles del Error '|| sqlerrm);


End;
Begin
   if inserting then
      lp_act_requerimiento(:new.cod_requerimiento, :new.mto_ejecutado);

   elsif updating then
      if :new.cod_requerimiento = :old.cod_requerimiento
      and nvl(:new.mto_ejecutado,0) <> nvl(:old.mto_ejecutado,0) then
         lp_act_requerimiento(:new.cod_requerimiento, (nvl(:new.mto_ejecutado,0)-nvl(:old.mto_ejecutado,0)));
      end if;
      if :new.cod_requerimiento <> :old.cod_requerimiento then
         lp_act_requerimiento(:new.cod_requerimiento, :new.mto_ejecutado);
         lp_act_requerimiento(:old.cod_requerimiento, (:old.mto_ejecutado * -1));
      end if;
   elsif deleting then
      lp_act_requerimiento(:old.cod_requerimiento, (:old.mto_ejecutado * -1));
   end if;
End;
/

