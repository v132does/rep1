CREATE OR REPLACE TRIGGER IT.TA_AP_REQUERIMIENTOS
 AFTER DELETE OR INSERT OR UPDATE
 ON AP_REQUERIMIENTOS
 FOR EACH ROW



DECLARE

/* Actualizacion de Montos Proyectos */
PROCEDURE LP_ACT_PROYECTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_MTO_EJECUTADO IN AP_PROYECTOS.MTO_EJECUTADO%TYPE
 );

/* Actualizacion de Montos Proyectos */
PROCEDURE LP_ACT_PROYECTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_MTO_EJECUTADO IN AP_PROYECTOS.MTO_EJECUTADO%TYPE
 )
 IS
Begin
--Actualiza el Monto Ejeuctado en Proyectos
   update ap_proyectos
   set mto_ejecutado = nvl(mto_ejecutado,0) + nvl(p_mto_ejecutado,0)
   where cod_plan = p_cod_plan
   and cod_proyecto = p_cod_proyecto;

exception
    when others then
        raise_application_error(-20000,'Act. Proyectos ' || to_char(p_cod_proyecto)
        || ' - ' || 'Ver Detalles del Error -'|| sqlerrm);

End;
Begin
Declare
    v_cod_grupo ap_grupos.cod_grupo%type;
Begin
   if inserting then
      if nvl(:new.mto_ejecutado,0) > 0 then
         lp_act_proyecto(:new.cod_plan, :new.cod_proyecto, :new.mto_ejecutado);
      end if;
      --Buscar cod_grupo al que pertenece el usuario
      v_cod_grupo := fuy_obt_grupo(:new.cod_usuario);
      --Inserta el primer nivel de aprobación
      pry_ins_aprobacion(v_cod_grupo, :new.cod_tip_requerimiento, :new.cod_requerimiento,0);

   elsif updating then
      ---Actualiza los montos en Proyectos
      if :new.cod_plan = :old.cod_plan
      and :new.cod_proyecto = :old.cod_proyecto
      and nvl(:new.mto_ejecutado,0) <> nvl(:old.mto_ejecutado,0) then
          lp_act_proyecto(:new.cod_plan, :new.cod_proyecto, (nvl(:new.mto_ejecutado,0)-nvl(:old.mto_ejecutado,0)));
      end if;
     if :new.cod_plan <> :old.cod_plan
       or :new.cod_proyecto <> :new.cod_proyecto then
          lp_act_proyecto(:new.cod_plan, :new.cod_proyecto, :new.mto_ejecutado);
          lp_act_proyecto(:old.cod_plan, :old.cod_proyecto, (:old.mto_ejecutado*-1));
       end if;
    end if;
End;
End;
/

