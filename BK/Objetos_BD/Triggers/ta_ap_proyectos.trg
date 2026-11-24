CREATE OR REPLACE TRIGGER IT.TA_AP_PROYECTOS
 AFTER DELETE OR INSERT OR UPDATE
 ON AP_PROYECTOS
 FOR EACH ROW


DECLARE

/* Actualiza Monto Presupuestado de Planes */
PROCEDURE LP_ACT_PLANES
 (P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 ,P_MTO_PRESUPUESTADO IN AP_PLANES.MTO_PRESUPUESTADO%TYPE
 ,P_MTO_EJECUTADO IN AP_PLANES.MTO_EJECUTADO%TYPE
 );

/* Actualiza Monto Presupuestado de Planes */
PROCEDURE LP_ACT_PLANES
 (P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 ,P_MTO_PRESUPUESTADO IN AP_PLANES.MTO_PRESUPUESTADO%TYPE
 ,P_MTO_EJECUTADO IN AP_PLANES.MTO_EJECUTADO%TYPE
 )
 IS
Begin

--Actualiza el monto presupuestado en Planes
update ap_planes
set mto_presupuestado = nvl(mto_presupuestado,0) + nvl(p_mto_presupuestado,0),
    mto_ejecutado = nvl(mto_ejecutado,0) + nvl(p_mto_ejecutado,0)
where cod_plan = p_cod_plan;

exception
    when others then
        raise_application_error(-20000,'Act. Plan ' || to_char(p_cod_plan) || ' - '
        || 'Ver Detalles del Error '|| sqlerrm);

End;
Begin
    if inserting then
        if nvl(:new.mto_presupuestado,0) > 0 then
           lp_act_planes(:new.cod_plan, :new.mto_presupuestado,0);
        end if;

        elsif updating then
        --Actualiza el Monto Presupuestado
        if :new.cod_plan = :old.cod_plan
        and nvl(:new.mto_presupuestado,0) <> nvl(:old.mto_presupuestado,0) then
            lp_act_planes(:new.cod_plan, (nvl(:new.mto_presupuestado,0)-nvl(:old.mto_presupuestado,0)),0);
        end if;
        if :new.cod_plan <> :old.cod_plan then
            lp_act_planes(:new.cod_plan, :new.mto_presupuestado, 0);
            lp_act_planes(:old.cod_plan, (:old.mto_presupuestado * -1), 0);
        end if;
        --Actualiza el Monto Ejecutado
        if :new.cod_plan = :old.cod_plan
        and nvl(:new.mto_ejecutado,0) <> nvl(:old.mto_ejecutado,0) then
            lp_act_planes(:new.cod_plan, 0, (nvl(:new.mto_ejecutado,0)-nvl(:old.mto_ejecutado,0)));
        end if;
        if :new.cod_plan <> :old.cod_plan then
            lp_act_planes(:new.cod_plan, :new.mto_ejecutado, 0);
            lp_act_planes(:old.cod_plan,0,(:old.mto_ejecutado* -1));
        end if;
    elsif deleting then
       lp_act_planes(:old.cod_plan, (:old.mto_presupuestado * -1), (:old.mto_ejecutado * -1));
    end if;

End;
/

