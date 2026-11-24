CREATE OR REPLACE TRIGGER IT.TB_AP_SEGUIMIENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_SEGUIMIENTOS
 FOR EACH ROW


DECLARE

/* Verifica que el requerimiento corresponda al proyecto */
PROCEDURE LP_VER_REQUERIMIENTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 );

/* Verifica que el requerimiento corresponda al proyecto */
PROCEDURE LP_VER_REQUERIMIENTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 )
 IS

V_ENCONTRO VARCHAR2(1);
BEGIN
   Select '1'
   into v_encontro
   from ap_requerimientos
   where cod_plan = p_cod_plan
   and cod_proyecto = p_cod_proyecto
   and cod_requerimiento = p_cod_requerimiento;

exception
   when no_data_found then
      raise_application_error(-20000,
      'Requerimiento: '|| to_char(p_cod_requerimiento)||
      'no corresponde a Proyecto '||to_char(p_cod_proyecto));
   when others then
      raise_application_error(-20001,
      'Error:lp_ver_requerimiento - '||sqlerrm);

END;
BEGIN
   if inserting then
      if :new.cod_requerimiento is not null then
         --Verifica que el Requerimiento corresponda al Proyecto
         lp_ver_requerimiento(:new.cod_plan, :new.cod_proyecto, :new.cod_requerimiento);
      end if;
   elsif updating then
      if :old.cod_requerimiento <> :new.cod_requerimiento then
         --Verifica que el Requerimiento corresponda al Proyecto
         lp_ver_requerimiento(:new.cod_plan, :new.cod_proyecto, :new.cod_requerimiento);
      end if;

      if  :old.usu_insercion <> substr(user,1,10) and
         (:new.cod_tip_seguimiento <> :old.cod_tip_seguimiento or
          :new.descripcion <> :old.descripcion or
          :new.fecha <> :old.fecha or
          :new.cod_requerimiento <> :old.cod_requerimiento or
          nvl(:new.detalles,'-') <> nvl(:old.detalles,'-')) then
          raise_application_error(-20000,
          'Solo el realizó el Informe de Seguimiento puede modificar');
       end if;
   end if;
END;
/

