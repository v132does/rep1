CREATE OR REPLACE TRIGGER IT."TB_AP_PROYECTOS" BEFORE INSERT OR DELETE OR UPDATE ON AP_PROYECTOS REFERENCING NEW AS NEW OLD AS OLD FOR EACH ROW

DECLARE

/* Verifica que los proyectos tengan requerimientos con situación CA/FI */
PROCEDURE LP_VER_SIT_REQ
 (P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 );
/* Validar que los requerimientos esten cancelados o finalizados */
PROCEDURE LP_VAL_REQUERIMIENTO
 (P_COD_PLAN IN AP_REQUERIMIENTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 );
/* Obtener fechas de inicio y fin de Planes */
PROCEDURE LP_OBT_FEC_PLAN
 (P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 ,P_FEC_INICIO OUT AP_PLANES.FEC_INICIO%TYPE
 ,P_FEC_FIN OUT AP_PLANES.FEC_FIN%TYPE
 );
/* Verifica el Permiso del Rol Gerente */
PROCEDURE LP_VER_ROL_GERENTE
 (P_COD_USUARIO IN AP_PROYECTOS.COD_USUARIO%TYPE
 ,P_ACCION IN VARCHAR2
 ,P_DESCRIPCION_NVO IN AP_PROYECTOS.DESCRIPCION%TYPE
 ,P_DESCRIPCION_VJO IN AP_PROYECTOS.DESCRIPCION%TYPE
 ,P_DES_DETALLADA_NVO IN AP_PROYECTOS.DES_DETALLADA%TYPE
 ,P_DES_DETALLADA_VJO IN AP_PROYECTOS.DES_DETALLADA%TYPE
 ,P_COD_OFICINA_NVO IN AP_PROYECTOS.COD_OFICINA%TYPE
 ,P_COD_OFICINA_VJO IN AP_PROYECTOS.COD_OFICINA%TYPE
 ,P_COD_AREA_NVO IN AP_PROYECTOS.COD_AREA%TYPE
 ,P_COD_AREA_VJO IN AP_PROYECTOS.COD_AREA%TYPE
 ,P_FEC_INICIO_NVO IN AP_PROYECTOS.FEC_INICIO%TYPE
 ,P_FEC_INICIO_VJO IN AP_PROYECTOS.FEC_INICIO%TYPE
 ,P_FEC_FIN_NVO IN AP_PROYECTOS.FEC_FIN%TYPE
 ,P_FEC_FIN_VJO IN AP_PROYECTOS.FEC_FIN%TYPE
 ,P_DURACION_NVO IN AP_PROYECTOS.DURACION%TYPE
 ,P_DURACION_VJO IN AP_PROYECTOS.DURACION%TYPE
 ,P_ORDEN_NVO IN AP_PROYECTOS.ORDEN%TYPE
 ,P_ORDEN_VJO IN AP_PROYECTOS.ORDEN%TYPE
 ,P_APROBADO_NVO IN AP_PROYECTOS.APROBADO%TYPE
 ,P_APROBADO_VJO IN AP_PROYECTOS.APROBADO%TYPE
 ,P_PRIORIDAD_NVO IN AP_PROYECTOS.PRIORIDAD%TYPE
 ,P_PRIORIDAD_VJO IN AP_PROYECTOS.PRIORIDAD%TYPE
 );

/* Verifica que los proyectos tengan requerimientos con situación CA/FI */
PROCEDURE LP_VER_SIT_REQ
 (P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 )
 IS
Begin
    Declare
        v_cant number(5);

    Begin

        select count(*)
        into v_cant
        from ap_requerimientos
        where cod_plan = p_cod_plan
        and cod_proyecto = p_cod_proyecto
        and ( situacion <> 'CA' or situacion <> 'FI');


        if v_cant > 0 then
            raise_application_error(-20000,'Proyecto posee requerimientos distintos a CA/FI');
        end if;
    End;
End;
/* Validar que los requerimientos esten cancelados o finalizados */
PROCEDURE LP_VAL_REQUERIMIENTO
 (P_COD_PLAN IN AP_REQUERIMIENTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 )
 IS
Begin
Declare
    v_cant  number(10);
Begin

    Select count(*)
    into v_cant
    from ap_requerimientos
    where cod_plan = p_cod_plan
    and cod_proyecto = p_cod_proyecto;

    if v_cant > 0 then
        raise_application_error(-20000,'Proyecto ' ||to_char(p_cod_proyecto) ||'posee Requerimientos');
    end if;
End;

End;
/* Obtener fechas de inicio y fin de Planes */
PROCEDURE LP_OBT_FEC_PLAN
 (P_COD_PLAN IN AP_PLANES.COD_PLAN%TYPE
 ,P_FEC_INICIO OUT AP_PLANES.FEC_INICIO%TYPE
 ,P_FEC_FIN OUT AP_PLANES.FEC_FIN%TYPE
 )
 IS
begin

   select fec_inicio, fec_fin
   into p_fec_inicio, p_fec_fin
   from ap_planes
   where cod_plan = p_cod_plan;

   dbms_output.put_line('fec_inicio - fec_fin'|| to_char(p_fec_inicio)||' - ' || to_char(p_fec_fin));

exception
   when no_data_found then
      raise_application_error(-20000,
      'Plan '||to_char(p_cod_plan)||' no registrado');
end;
/* Verifica el Permiso del Rol Gerente */
PROCEDURE LP_VER_ROL_GERENTE
 (P_COD_USUARIO IN AP_PROYECTOS.COD_USUARIO%TYPE
 ,P_ACCION IN VARCHAR2
 ,P_DESCRIPCION_NVO IN AP_PROYECTOS.DESCRIPCION%TYPE
 ,P_DESCRIPCION_VJO IN AP_PROYECTOS.DESCRIPCION%TYPE
 ,P_DES_DETALLADA_NVO IN AP_PROYECTOS.DES_DETALLADA%TYPE
 ,P_DES_DETALLADA_VJO IN AP_PROYECTOS.DES_DETALLADA%TYPE
 ,P_COD_OFICINA_NVO IN AP_PROYECTOS.COD_OFICINA%TYPE
 ,P_COD_OFICINA_VJO IN AP_PROYECTOS.COD_OFICINA%TYPE
 ,P_COD_AREA_NVO IN AP_PROYECTOS.COD_AREA%TYPE
 ,P_COD_AREA_VJO IN AP_PROYECTOS.COD_AREA%TYPE
 ,P_FEC_INICIO_NVO IN AP_PROYECTOS.FEC_INICIO%TYPE
 ,P_FEC_INICIO_VJO IN AP_PROYECTOS.FEC_INICIO%TYPE
 ,P_FEC_FIN_NVO IN AP_PROYECTOS.FEC_FIN%TYPE
 ,P_FEC_FIN_VJO IN AP_PROYECTOS.FEC_FIN%TYPE
 ,P_DURACION_NVO IN AP_PROYECTOS.DURACION%TYPE
 ,P_DURACION_VJO IN AP_PROYECTOS.DURACION%TYPE
 ,P_ORDEN_NVO IN AP_PROYECTOS.ORDEN%TYPE
 ,P_ORDEN_VJO IN AP_PROYECTOS.ORDEN%TYPE
 ,P_APROBADO_NVO IN AP_PROYECTOS.APROBADO%TYPE
 ,P_APROBADO_VJO IN AP_PROYECTOS.APROBADO%TYPE
 ,P_PRIORIDAD_NVO IN AP_PROYECTOS.PRIORIDAD%TYPE
 ,P_PRIORIDAD_VJO IN AP_PROYECTOS.PRIORIDAD%TYPE
 )
 IS
v_msj varchar2(50);
BEGIN
     if p_accion = 'U' then
        v_msj := 'Modificar';
     else
        v_msj := 'Eliminar';
     end if;
     if fuy_es_gerente_ti(p_cod_usuario)= 'N' then
         if (p_descripcion_nvo <> p_descripcion_vjo)or
            (p_des_detallada_nvo <> p_des_detallada_vjo) or
            (p_cod_oficina_nvo <> p_cod_oficina_vjo) or
            (p_cod_area_nvo <> p_cod_area_vjo) or
            (p_fec_inicio_nvo <> p_fec_inicio_vjo) or
            (p_fec_fin_nvo <> p_fec_fin_vjo) or
            (p_duracion_nvo <> p_duracion_vjo)or
            (p_orden_nvo <> p_orden_vjo)or
            (p_aprobado_nvo <> p_aprobado_vjo)or
            (p_prioridad_nvo <> p_prioridad_vjo) then

            raise_application_error(-20000,
            ' No pertenece al Rol Gerente TI, no puede '||v_msj);

         end if;
      end if;

END;
Begin
declare
   v_categoria      ba_usuarios.categoria%type;
   v_fec_inicio     ap_planes.fec_inicio%type;
   v_fec_fin        ap_planes.fec_fin%type;

Begin
   if inserting then
    -- Verificar si el usuario es Supervisor de Tecnologia
      v_categoria := fuy_obt_cat_usuario(:new.cod_usuario);
      if v_categoria = 'US' then
         raise_application_error(-20000,
         'El Usuario debe ser Supervisor de Tecnología o Miembro de TI');
      end if;
      -- Verificar que la fecha de Inicio no sea menor que la fecha de Inicio del Proyecto.
      lp_obt_fec_plan(:new.cod_plan, v_fec_inicio, v_fec_fin);
      if :new.fec_inicio < v_fec_inicio then
         raise_application_error(-20000,
         'La Fecha de Inicio del Proyecto no puede ser menor a la del Plan');
      end if;
      if :new.fec_fin > v_fec_fin then
          raise_application_error(-20000,
         'La Fecha de Fin del Proyecto no puede ser mayor a la del Plan');
      end if;
   elsif updating then
      --Valida el Rol del Usuario
      lp_ver_rol_gerente(user,'U',:new.descripcion, :old.descripcion,
                        :new.des_detallada, :old.des_detallada,
                        :new.cod_oficina,:old.cod_oficina, :new.cod_area,:old.cod_area,
                        :new.fec_inicio,:old.fec_inicio,:new.fec_fin, :old.fec_fin,
                        :new.duracion,:old.duracion,:new.orden,:old.orden,
                        :new.aprobado,:old.aprobado,:new.prioridad,:old.prioridad);
      --Verifica la Categoria del Usuario
      if :old.cod_usuario <> :new.cod_usuario then
         -- Verificar si el usuario es Supervisor de Tecnologia
         v_categoria := fuy_obt_cat_usuario(:new.cod_usuario);
         if v_categoria = 'US' then
            raise_application_error(-20000,
            'El Usuario debe ser Supervisor de Tecnología o Miembro de TI');
         end if;
      end if;
      -- Valida que los Requerimientos sean CA/FI para
      -- cambiar la Situación del Proyecto a Finalizado o Cancelado
      if :new.situacion = 'FI' or :new.situacion = 'CA' then
         lp_ver_sit_req(:new.cod_plan, :new.cod_proyecto);
      end if;
      -- Valida que no posea requerimientos
      if :old.aprobado = 'S' and :new.aprobado = 'N' then
         lp_val_requerimiento(:new.cod_plan, :new.cod_proyecto);
      end if;
      --- Actualizar Porcentaje Ejecutado
      if nvl(:new.mto_presupuestado,0) <> nvl(:old.mto_presupuestado,0)
      or nvl(:new.mto_ejecutado,0) <> nvl(:old.mto_ejecutado,0)then
         if nvl(:new.mto_presupuestado,0) = 0 and nvl(:new.mto_ejecutado,0) > 0  then
            :new.por_ejecutado := 0;
         end if;
         if nvl(:new.mto_presupuestado,0) > 0 and nvl(:new.mto_ejecutado,0) > 0  then
            :new.por_ejecutado := round(nvl(:new.mto_ejecutado,0)/nvl(:new.mto_presupuestado,0)*100,2);
         end if;
      end if;
       -- Verificar que la fecha de Inicio no sea menor que la fecha de Inicio del Proyecto.
      lp_obt_fec_plan(:new.cod_plan, v_fec_inicio, v_fec_fin);
      if :new.fec_inicio < v_fec_inicio then
         raise_application_error(-20000,
         'La Fecha de Inicio del Proyecto no puede ser menor a la del Plan');
      end if;
      if :new.fec_fin > v_fec_fin then
          raise_application_error(-20000,
         'La Fecha de Fin del Proyecto no puede ser mayor a la del Plan');
      end if;
   elsif deleting then
      --Valida el Rol del Usuario
      lp_ver_rol_gerente(user,'U',:new.descripcion, :old.descripcion,
                        :new.des_detallada, :old.des_detallada,
                        :new.cod_oficina,:old.cod_oficina, :new.cod_area,:old.cod_area,
                        :new.fec_inicio,:old.fec_inicio,:new.fec_fin, :old.fec_fin,
                        :new.duracion,:old.duracion,:new.orden,:old.orden,
                        :new.aprobado,:old.aprobado,:new.prioridad,:old.prioridad);

      -- No permitir el borrado cuando el Proyecto está aprobado.
      if :old.aprobado = 'S' then
         raise_application_error(-20000, 'Proyecto ' || to_char(:old.cod_proyecto) || 'aprobado');
      end if;
   end if;
End;

End;
/

