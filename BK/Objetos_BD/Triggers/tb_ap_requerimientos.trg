CREATE OR REPLACE TRIGGER IT.TB_AP_REQUERIMIENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_REQUERIMIENTOS
 FOR EACH ROW


DECLARE

/* Verificar aprobación del Proyecto */
PROCEDURE LP_VER_APR_PROYECTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 );
/* Obtiene las fechas de inicio y fin de un Proyecto */
PROCEDURE LP_OBT_FEC_PROYECTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_FEC_INICIO OUT AP_PROYECTOS.FEC_INICIO%TYPE
 ,P_FEC_FIN OUT AP_PROYECTOS.FEC_FIN%TYPE
 );
/* Obtener Cantidad de Desarrollos Transferidos para un Requerimiento */
FUNCTION LF_OBT_DES_TRANSFER
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 )
 RETURN INTEGER;

/* Verificar aprobación del Proyecto */
PROCEDURE LP_VER_APR_PROYECTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 )
 IS
Begin
    declare
       v_aprobado ap_proyectos.aprobado%type;
    Begin

       select aprobado
       into v_aprobado
       from ap_proyectos
       where cod_plan = p_cod_plan
       and cod_proyecto = p_cod_proyecto;

       if v_aprobado = 'N' then
          raise_application_error(-20000,
          'El Proyecto '||to_char(p_cod_proyecto)||' Plan'||to_char(p_cod_plan) ||' no está aprobado');
       end if;
    End;
End;
/* Obtiene las fechas de inicio y fin de un Proyecto */
PROCEDURE LP_OBT_FEC_PROYECTO
 (P_COD_PLAN IN AP_PROYECTOS.COD_PLAN%TYPE
 ,P_COD_PROYECTO IN AP_PROYECTOS.COD_PROYECTO%TYPE
 ,P_FEC_INICIO OUT AP_PROYECTOS.FEC_INICIO%TYPE
 ,P_FEC_FIN OUT AP_PROYECTOS.FEC_FIN%TYPE
 )
 IS
begin

   select fec_inicio, fec_fin
   into p_fec_inicio, p_fec_fin
   from ap_proyectos
   where cod_plan = p_cod_plan
   and cod_proyecto = p_cod_proyecto;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Proyecto '||p_cod_proyecto||' no registrado');
end;
/* Obtener Cantidad de Desarrollos Transferidos para un Requerimiento */
FUNCTION LF_OBT_DES_TRANSFER
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 )
 RETURN INTEGER
 IS

V_CANT NUMBER(6);
BEGIN
   --Verifica si el Requerimientos posee desarrollos Transferidos

   select count(*)
   into v_cant
   from ap_desarrollos
   where cod_requerimiento = p_cod_requerimiento
   and estado <> 'TR';

   if v_cant = 0 then
      return v_cant;
   end if;

  return v_cant;

exception
   when others then

      raise_application_error(-20001,
      'lf_obt_des_transfer'||sqlerrm);
END;
begin
declare
   v_categoria      ba_usuarios.categoria%type;
   v_fec_fin        ap_proyectos.fec_fin%type;
   v_fec_ini        ap_proyectos.fec_inicio%type;
   v_errores        varchar2(250) null;
   v_cod_grupo      ap_grupos.cod_grupo%type;
   v_cod_gru_aprueba ap_grupos.cod_grupo%type;
   v_existe          number(1);

begin
   if inserting then
      if :new.cod_tip_requerimiento is null then
         raise_application_error(-20000,
         'El tipo de requerimiento no puede ser nulo');
      end if;
      if :new.cod_usuario is null then
         :new.cod_usuario := substr(USER, 1,10);
      END IF;

      --Buscar cod_grupo al que pertenece el usuario
      v_cod_grupo := fuy_obt_grupo(:new.cod_usuario);
      --Verifica que el circuito de Aprobación esté completo
      pry_ver_circuito(v_cod_grupo, :new.cod_tip_requerimiento);

      /* Se informa a nivel de form si el rango de fechas no corresponden, pero igual
         se graba la información en tal caso, 04-05-2004, CDE.
      -- Verificar que la fecha de Inicio no sea menor que la fecha de Inicio del Proyecto.
      lp_obt_fec_proyecto(:new.cod_plan,:new.cod_proyecto, v_fec_ini, v_fec_fin);
      if :new.fec_inicio < v_fec_ini then
         raise_application_error(-20000,
         'La Fecha de Inicio '|| to_char(:new.fec_inicio,'DD/MM/YYYY')||
         ' del Requerimiento no puede ser menor a la del Proyecto '||to_char(v_fec_ini,'DD/MM/YYYY'));
      end if;
      if :new.fec_fin > v_fec_fin then
         raise_application_error(-20001,
         'La Fecha de Fin  '|| to_char(:new.fec_fin,'DD/MM/YYYY')||
         ' del Requerimiento no puede ser mayor a la del Proyecto '||to_char(v_fec_fin,'DD/MM/YYYY'));
      end if;
      */
   elsif updating then
      ---Verifica la modificación de descripcion y des_detallada.
      ---Modificado: 03-05-2004, CDE
      ---El usuario que solicita solo puede modificar y el Req. no debe estar aprobado
      if (:new.des_detallada <> :old.des_detallada) or
         (:new.descripcion <> :old.descripcion )then
         if :new.cod_usuario <> user and
            :new.estado <> 'A' then
            raise_application_error(-20000,
            'Modificación permitida solo para el que Solicitó el Requerimiento');
         elsif :new.cod_usuario = user and
               :new.estado = 'A' then
            raise_application_error(-20001,
            'El Requerimiento esta aprobado, no puede modificar');
         end if;
      end if;
      --Verifica que el usuario que modifica pertenezca al rol: ITAP_GERENTE_TI
      --Modificado: 24-04-2004, CDE
      if fuy_es_gerente_ti(user)= 'N' then
         if (:new.fec_inicio <> :old.fec_inicio) or
            (:new.fec_fin <> :old.fec_fin) or
            (nvl(:new.fec_ini_real,sysdate) <> nvl(:old.fec_ini_real,sysdate)) or
            (nvl(:new.fec_fin_real,sysdate) <> nvl(:old.fec_fin_real,sysdate)) or
            (nvl(:new.duracion,0) <> nvl(:old.duracion,0))or
            (nvl(:new.orden,0) <> nvl(:old.orden,0))or
            (:new.prioridad <> :old.prioridad) then
            raise_application_error(-20000,
            'No pertenece al rol ITAP_GERENTE_TI, no puede Modificar');
         end if;
      end if;
      -- Verificar el cambio del Usuario Responsable
      if nvl(:new.cod_usu_responsable,'-') <> nvl(:old.cod_usu_responsable,'-') then
         v_categoria := fuy_obt_cat_usuario(substr(user,1,10));
         if v_categoria <> 'ST' then
            raise_application_error(-20000,
            user || ' No está autorizado a modificar el Responsable');
         end if;
         v_categoria := fuy_obt_cat_usuario(:new.cod_usu_responsable);
         if v_categoria = 'US' then
            raise_application_error(-20000,
            'Usuario responsable debe ser Miembro de TI o Supervisor TI');
         end if;
      end if;
      --Verificaciones varias
      if :new.cod_usuario is null then
         v_errores := v_errores || ' Solicitante, ';
      end if;
      --Cambia la situación del Requerimiento si tuvo un pago
      if nvl(:old.mto_ejecutado,0) = 0 and
         nvl(:new.mto_ejecutado,0) > 0 then
         :new.situacion := 'DE';
      end if;
      if :new.situacion <> 'NI'or
         :new.cod_proyecto is not null or
         :new.cod_usu_responsable is not null then
         --Validar ingreso de Datos
         if :new.cod_proyecto is null then
            v_errores := 'Cod.Proyecto, ';
         end if;
         if :new.cod_usu_responsable is null then
            v_errores := v_errores || ' Responsable,';
         end if;
         if :new.fec_inicio is null then
            v_errores := v_errores || ' Fecha de Inicio, ';
         end if;
         if :new.fec_fin is null then
            v_errores := v_errores || ' Fecha Fin,';
         end if;
         if v_errores is not null then
            v_errores := substr(v_errores,1,length(v_errores) - 1);
            raise_application_error(-20000,
            v_errores || ' Debe(n) Ingresarse');
         end if;
         --Verificar si el Requerimiento tiene Desarrollos no Transferidos
         --Si tiene no se puede cambiar la Situación a Finalizado
         if :new.situacion <> :old.situacion and
            :new.situacion = 'FI' then
            if lf_obt_des_transfer(:new.cod_requerimiento)> 0 then
                 raise_application_error(-20001,
                 'Existen Desarrollos No Transferidos');
            end if;
         end if;
         -- Verificar que el Proyecto sea aprobado
         if :new.cod_proyecto is not null then
            lp_ver_apr_proyecto(:new.cod_plan, :new.cod_proyecto);
         end if;

         /* Se informa a nivel de form si el rango de fechas no corresponden, pero igual
         se graba la información en tal caso, 04-05-2004, CDE.
         -- Verificar que la fecha de Inicio no sea menor que la fecha de Inicio del Proyecto.
         lp_obt_fec_proyecto(:new.cod_plan,:new.cod_proyecto, v_fec_ini, v_fec_fin);
         if :new.fec_inicio < v_fec_ini then
            raise_application_error(-20000,
            'La Fecha de Inicio '|| to_char(:new.fec_inicio,'DD/MM/YYYY')||
             ' del Requerimiento no puede ser menor a la del Proyecto '||to_char(v_fec_ini,'DD/MM/YYYY'));
         end if;
         if :new.fec_fin > v_fec_fin then
            raise_application_error(-20000,
            'La Fecha de Fin  '|| to_char(:new.fec_fin,'DD/MM/YYYY')||
            ' del Requerimiento no puede ser mayor a la del Proyecto '||to_char(v_fec_fin,'DD/MM/YYYY'));
         end if;*/
      end if;
      if :new.cod_proyecto is not null
      and :new.cod_usuario is not null
      and :new.fec_inicio is not null
      and :new.fec_fin is not null
      and :new.estado = 'P' then
         raise_application_error(-20000,
         'El requerimiento no está aprobado');
      end if;

   elsif deleting then
      if :old.estado = 'A' then
         raise_application_error(-20000,
         'No se puede eliminar un Requerimiento Aprobado');
      end if;
   end if;
end;
end;
/

