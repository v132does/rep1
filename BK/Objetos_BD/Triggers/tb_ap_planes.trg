CREATE OR REPLACE TRIGGER IT.TB_AP_PLANES
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_PLANES
 FOR EACH ROW


DECLARE

/* Valida las fechas de Incio y Fin del Plan */
PROCEDURE LP_VAL_FEC_PLAN
 (P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 ,P_FEC_INICIO IN AP_PLANES.FEC_INICIO%TYPE
 ,P_FEC_FIN IN AP_PLANES.FEC_FIN%TYPE
 );

/* Valida las fechas de Incio y Fin del Plan */
PROCEDURE LP_VAL_FEC_PLAN
 (P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 ,P_FEC_INICIO IN AP_PLANES.FEC_INICIO%TYPE
 ,P_FEC_FIN IN AP_PLANES.FEC_FIN%TYPE
 )
 IS
begin
declare
    v_fec_inicio ap_proyectos.fec_inicio%type;
    v_fec_fin ap_proyectos.fec_fin%type;
begin
   Select min(fec_inicio), max(fec_fin)
   into v_fec_inicio, v_fec_fin
   from ap_proyectos
   where cod_plan = p_cod_plan;

   --Validar que la Fecha de Inicio sea menor o igual a las fecha de Inicio de los proyectos del plan.
   if p_fec_inicio > v_fec_inicio then
      raise_application_error(-20000,
      'Fecha de Inicio debe ser menor a las fechas de Inicios de sus Proyectos');
   end if;
   -- Validar que la Fecha Fin sean mayor o igual a las fechas fin de los proyectos del plan
   if p_fec_fin < v_fec_fin then
       raise_application_error(-20000,
      'Fecha de Inicio debe ser menor a las fechas de Inicios de sus Proyectos');
   end if;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Proyectos no registrados para el Plan '||to_char(p_cod_plan));
end;
end;
Begin
declare
   v_categoria      ba_usuarios.categoria%type;
Begin
   if inserting then
       -- Verificar si el usuario es Supervisor de Tecnologia
      v_categoria := fuy_obt_cat_usuario(substr(user,1,10));
      if v_categoria = 'UT' then
         raise_application_error(-20000,
         'El Usuario debe ser Supervisor de Tecnología o Miembro de TI');
      end if;
   elsif updating then
       --- Actualizar Porcentaje Ejecutado
      if nvl(:new.mto_presupuestado,0) <> nvl(:old.mto_presupuestado,0)
      or nvl(:new.mto_ejecutado,0) <> nvl(:old.mto_ejecutado,0)then
         if nvl(:new.mto_presupuestado,0) = 0 and nvl(:new.mto_ejecutado,0) > 0  then
            :new.por_ejecutado := 0;
         else
            :new.por_ejecutado := round(nvl(:new.mto_ejecutado,0)/nvl(:new.mto_presupuestado,0)*100,2);
         end if;
      end if;

      if fuy_es_gerente_ti(user) = 'N' and
         (:new.descripcion <> :old.descripcion or
          :new.des_detallada <> :old.des_detallada or
          :new.tipo <> :old.tipo or
          :new.estado <> :old.estado or
          :new.fec_inicio <> :old.fec_inicio or
          :new.fec_fin <> :old.fec_fin or
          :new.fec_ini_real <> :old.fec_ini_real or
          :new.fec_fin_real <> :old.fec_fin_real or
          :new.ano_creacion <> :old.ano_creacion) then
          raise_application_error(-20000,
          User ||' No pertenece al Rol Gerente_TI, no puede modificar el registro');
      end if;

      -- Verificar si el usuario es Supervisor de Tecnologia
      v_categoria := fuy_obt_cat_usuario(substr(user,1,10));
      if v_categoria = 'US' then
         raise_application_error(-20000,
         'El Usuario debe ser Supervisor de Tecnología o Miembro de TI');
      end if;

      --Validar que la Fecha de Inicio sea menor o igual a las fecha de Inicio de los proyectos del plan.
      --Validar que la Fecha Fin sean mayor o igual a las fechas fin de los proyectos del plan
      /*if :old.fec_inicio <> :new.fec_inicio
      or :old.fec_fin <> :new.fec_inicio then
        lp_val_fec_plan(:new.cod_plan, :new.fec_inicio, :new.fec_fin);
      end if;     */
   elsif deleting then
      if fuy_es_gerente_ti(user) = 'N' then
         raise_application_error(-20000,
         'El Usuario no pertenece al Rol: Gerente_TI, no puede eliminar el registro');
      end if;
   end if;
end;
end;
/

