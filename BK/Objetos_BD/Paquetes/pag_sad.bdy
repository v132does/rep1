create or replace package body it.pag_sad is

/*
Creado para el proyecto Modificacion de datos sensibles en ITGF
2018.
*/

/*
Procedimiento que inserta los datos de las tablas originales ba_* a las tablas de solicitudes ge_sol_act*
para la persona consultada desde la pantalla GMACTDAT.
*/
  procedure pr_ins_datos( p_cod_persona IN ba_personas.cod_persona%TYPE, p_nro_solicitud in number default null)
    IS
     PRAGMA AUTONOMOUS_TRANSACTION;

    v_est_sol           ge_sol_act_datos.estado%type;
    v_nro_solicitud     ge_sol_act_datos.nro_solicitud%type;
    v_fec_actual        date;
    v_cod_oficina       ge_sol_act_datos.cod_oficina%type;
    v_tipo              ge_sol_act_personas.tipo%type;
    v_cod_tip_documento ge_sol_act_personas.cod_tip_documento%type;
    v_nro_documento     ge_sol_act_personas.nro_documento%type;
    v_dir_correo        ge_sol_act_personas.dir_correo%type;
    v_cod_pai_documento ge_sol_act_personas.cod_pai_documento%type;
    v_fec_vto_documento ge_sol_act_personas.fec_vto_documento%type;
    v_tie_cambios       varchar2(8) := 'N';

    BEGIN

    if p_cod_persona is not null then
      --1 Tiene que validar que no existan solicitudes en curso para insertar los registros.
     begin
       select estado
         into v_est_sol
         from ge_sol_act_datos a
        where a.cod_persona = p_cod_persona
          and a.nro_solicitud =
              (select max(nro_solicitud)
                 from ge_sol_act_datos
                where cod_persona = p_cod_persona);
     exception
       when no_data_found then
         v_est_sol := null;
       when others then
         raise_application_error(-20000, 'Obt_datos. '||sqlerrm);
     end;

      --2 inserta los registros en las tablas si no tiene nada en proceso ( PVE, RCH)
      if NVL(v_est_sol,'ING') in ('VEN', 'CAN', 'APR','ING') then
        -- 2.1 obtengo datos
        if p_nro_solicitud is null then
           select S_NRO_SOL_ACT_DATOS.nextval into v_nro_solicitud from dual;
        else -- si viene en el parametro
            v_tie_cambios   := pag_sad.fu_tie_modificaciones(p_nro_solicitud);
            v_nro_solicitud := p_nro_solicitud;
        end if;
        --
        v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);

        v_cod_oficina := fug_obt_ofi_usuario(upper(user));
        -- obtengo datos de persoans
        select tipo,               cod_tip_documento,               nro_documento,
               dir_correo,         cod_pai_documento,               fec_vto_documento
          into v_tipo,             v_cod_tip_documento,             v_nro_documento,
               v_dir_correo,       v_cod_pai_documento,             v_fec_vto_documento
          from ba_personas
         where cod_persona = p_cod_persona;

        -- 2.1 inserta la cabecera solicitud
        if  v_tie_cambios ='N' then
          begin
            insert into ge_sol_act_datos(nro_solicitud,cod_persona,fec_solicitud,estado,cod_usuario,cod_oficina)
            values (v_nro_solicitud, p_cod_persona, v_fec_actual, 'ING', upper(USER), v_cod_oficina);
          exception
            when others then
              raise_application_error(-20000, 'Ins_datos. '||sqlerrm);
          end ;
        end if;
        --2.2 inserta direcciones
        -- si en v_tie_cambios no existe 'D' no tiene nada en direcciones, vuelve a insertar
        if instr(v_tie_cambios,'D') = 0 then
          begin
            insert into ge_sol_act_direcciones(nro_solicitud, cod_persona, cod_direccion, tipo, principal, direccion,
                                               cod_pais, cod_ciudad, cod_barrio, observacion, numero, departamento, piso, edificio, cod_postal ,dir_lateral, tip_modificacion)
              select v_nro_solicitud, p_cod_persona, cod_direccion, tipo, principal, direccion,
                     cod_pais, cod_ciudad, cod_barrio, observacion, numero, departamento, piso, edificio, cod_postal, dir_lateral, 'N'
               from ba_direcciones
               where cod_persona = p_cod_persona;
          exception
             when others then
              raise_application_error(-20001, 'Ins_datos Dir. '||sqlerrm);
          end;
        end if;
        --2.3 inserta telefonos
        -- si en v_tie_cambios no existe 'T' no tiene nada en telefonos, vuelve a insertar
        if instr(v_tie_cambios,'T') = 0 then
          begin
            insert into ge_sol_act_telefonos(nro_solicitud,cod_persona,cod_telefono,tipo,tip_linea,telefono,principal,area,interno,observacion, tip_modificacion)
              select v_nro_solicitud, p_cod_persona, cod_telefono, tipo, tip_linea, telefono, principal, area, interno, observacion, 'N'
                from ba_telefonos
              where cod_persona = p_cod_persona;
          exception
             when others then
              raise_application_error(-20002, 'Ins_datos Telef. '||sqlerrm);
          end;
        end if;
        --2.4 inserta mails
        -- si en v_tie_cambios no existe 'M' no tiene nada en mails, vuelve a insertar
        if instr(v_tie_cambios,'M') = 0 then
          begin
            insert into ge_sol_act_mails
              (nro_solicitud,
               cod_persona,
               tipo,
               dir_correo,
               principal,
               observacion,
               tipo_ant,  -- tipo_ant y dir_correo_ant son campos para no perder la PK y poder hacer las act. posteriormente
               dir_correo_ant,
               tip_modificacion)
              select v_nro_solicitud,
                     p_cod_persona,
                     tipo,
                     dir_correo,
                     principal,
                     observacion,
                     tipo,
                     dir_correo,
                     'N'
                from ba_mails
               where cod_persona = p_cod_persona;
          exception
            when others then
              raise_application_error(-20003,
                                      'Ins_datos Mails. ' || sqlerrm);
          end;
        end if;
        --2.5 inserta direccion de envios
        -- si en v_tie_cambios no existe 'E' no tiene nada en direcciones de envios, vuelve a insertar
        if instr(v_tie_cambios,'E') = 0 then
           begin
             insert into ge_sol_act_dir_envios
               (nro_solicitud,
                cod_persona,
                tip_envio,
                referencia,
                nro_cuenta,
                observacion,
                nro_cuenta_ant, -- nro_cuenta forma parte de la PK, para no perder el dato original por si cambien
                tip_modificacion)
               select v_nro_solicitud,
                      p_cod_persona,
                      tip_envio,
                      referencia,
                      nro_cuenta,
                      observacion,
                      nro_cuenta,
                      'N'
                 from ge_dir_envios a
                where cod_persona = p_cod_persona;
          exception
             when others then
              raise_application_error(-20004, 'Ins_datos Mails. '||sqlerrm);
          end;
        end if;
        --2.6 inserta personas
        -- si en v_tie_cambios no existe 'P' no tiene nada en Personas, vuelve a insertar
        if instr(v_tie_cambios,'P') = 0 then
          if v_tipo = 'F' then -- p. fisicas
            begin
              insert into ge_sol_act_personas
                (nro_solicitud,
                 cod_persona,
                 tipo,
                 cod_tip_documento,
                 nro_documento,
                 fec_vto_documento,
                 cod_pai_documento,
                 dir_correo,
                 pri_nombre,
                 pri_apellido,
                 seg_nombre,
                 seg_apellido,
                 fec_nacimiento,
                 tip_modificacion,
                 est_civil
                 )
                select v_nro_solicitud,
                       p_cod_persona,
                       v_tipo,
                       v_cod_tip_documento,
                       v_nro_documento,
                       v_fec_vto_documento,
                       v_cod_pai_documento,
                       v_dir_correo,
                       pri_nombre,
                       pri_apellido,
                       seg_nombre,
                       seg_apellido,
                       fec_nacimiento,
                       'N',
                       est_civil
                  from ba_per_fisicas
                 where cod_persona = p_cod_persona;
            exception
               when others then
                raise_application_error(-20005, 'Ins_datos Per.Fisicas. '||sqlerrm);
            end;
          else
            begin
              insert into ge_sol_act_personas
                (nro_solicitud,
                 cod_persona,
                 tipo,
                 cod_tip_documento,
                 nro_documento,
                 fec_vto_documento,
                 cod_pai_documento,
                 dir_correo,
                 raz_social,
                 nom_comercial,
                 fec_apertura,
                 naturaleza,
                 tip_modificacion
                 )
                select v_nro_solicitud,
                       p_cod_persona,
                       v_tipo,
                       v_cod_tip_documento,
                       v_nro_documento,
                       v_fec_vto_documento,
                       v_cod_pai_documento,
                       v_dir_correo,
                       raz_social,
                       nom_comercial,
                       fec_apertura,
                       naturaleza,
                       'N'
                  from ba_per_juridicas
                 where cod_persona = p_cod_persona;
            exception
               when others then
                raise_application_error(-20006, 'Ins_datos Per.Juridicas. '||sqlerrm);
            end;
          end if;
        end if;
        --2.7 inserta parametros adicionales de cuentas
        -- si en v_tie_cambios no existe 'A' no tiene nada en adicionales de cuentas, vuelve a insertar
        if instr(v_tie_cambios,'A') = 0 then
          begin
            insert into GE_SOL_ACT_PAR_CUENTAS
              (nro_solicitud,
               cod_persona,
               parametro,
               nro_cuenta,
               valor,
               tip_modificacion)
              select v_nro_solicitud,
                     p_cod_persona,
                     c.parametro,
                     c.nro_cuenta,
                     c.val_parametro,
                     'N'
                from ge_Cta_clientes        cli,
                     ge_cuentas             a,
                     ge_est_cuentas         b,
                     ge_cta_dat_adicionales c
               where cli.nro_cuenta = a.nro_cuenta
                 and cli.cod_modulo = a.cod_modulo
                 and cli.cod_modalidad = a.cod_modalidad
                 and a.nro_cuenta = c.nro_cuenta
                 and a.cod_modulo = b.cod_modulo
                 and a.cod_modalidad = b.cod_modalidad
                 and a.estado = b.estado
                 and cli.cod_persona = p_cod_persona
                 and cli.relacion = 'P'
                 and c.parametro = 'EMAIL_ENVIO_EXT_ASCII'
                 and b.activo = 'S';
           exception
               when others then
                raise_application_error(-20007, 'Ins_datos Par.Cuentas '||sqlerrm);
           end;
        end if;
        --
        commit;
        --
      end if;
    end if;
     exception
       when others then
           raise_application_error(-20010, 'Ins_datos_sensibles '||sqlerrm);
    END pr_ins_datos;

    /*
    Procedimiento que elimina los registros de las tablas si no tiene cambios en ninguno de los registros Tip_Modificacion <> 'N',
    de manera que se vuelvan a insertar los registros en las tablas (esto hace desde el form gmactdat)
    */
    PROCEDURE pr_eli_solicitud( p_nro_solicitud IN ge_sol_act_datos.nro_solicitud%TYPE)  is
    PRAGMA AUTONOMOUS_TRANSACTION;

    v_tiene_cambios varchar2(8) := 'N';
    BEGIN

      v_tiene_cambios := pag_sad.fu_tie_modificaciones(p_nro_solicitud);


    -- SI NO SE REGISTRA CAMBIOS EN NINGUNA TABLAS, SE ELIMINAN LOS REGISTROS DE TODAS LAS TABLAS
     IF v_tiene_cambios ='N' THEN
       DELETE FROM GE_SOL_ACT_DIRECCIONES WHERE NRO_SOLICITUD = p_nro_solicitud;
       DELETE FROM GE_SOL_ACT_TELEFONOS WHERE NRO_SOLICITUD = p_nro_solicitud;
       DELETE FROM GE_SOL_ACT_MAILS WHERE NRO_SOLICITUD = p_nro_solicitud;
       DELETE FROM GE_SOL_ACT_PERSONAS WHERE NRO_SOLICITUD = p_nro_solicitud;
       DELETE FROM GE_SOL_ACT_DIR_ENVIOS WHERE NRO_SOLICITUD = p_nro_solicitud;
       DELETE FROM GE_SOL_ACT_PAR_CUENTAS WHERE NRO_SOLICITUD = p_nro_solicitud;
       DELETE FROM GE_SOL_ACT_DATOS WHERE NRO_SOLICITUD = p_nro_solicitud;
     END IF;

     -- si no hay cambios en personas eliminamos para que se cargue de vuelta
     if instr(v_tiene_cambios,'P') = 0 then
       DELETE FROM GE_SOL_ACT_PERSONAS WHERE NRO_SOLICITUD = p_nro_solicitud;
     end if;
     -- si no hay cambios en direcciones eliminamos para que se cargue de vuelta
     if instr(v_tiene_cambios,'D') = 0 then
       DELETE FROM GE_SOL_ACT_DIRECCIONES WHERE NRO_SOLICITUD = p_nro_solicitud;
     end if;
     -- si no hay cambios en telefonos eliminamos para que se cargue de vuelta
     if instr(v_tiene_cambios,'T') = 0 then
       DELETE FROM GE_SOL_ACT_TELEFONOS WHERE NRO_SOLICITUD = p_nro_solicitud;
     end if;
     -- si no hay cambios en mails eliminamos para que se cargue de vuelta
     if instr(v_tiene_cambios,'M') = 0 then
       DELETE FROM GE_SOL_ACT_MAILS WHERE NRO_SOLICITUD = p_nro_solicitud;
     end if;
     -- si no hay cambios en dir.envios eliminamos para que se cargue de vuelta
     if instr(v_tiene_cambios,'E') = 0 then
       DELETE FROM GE_SOL_ACT_DIR_ENVIOS WHERE NRO_SOLICITUD = p_nro_solicitud;
     end if;
     -- si no hay cambios en parametros adicionales eliminamos para que se cargue de vuelta
     if instr(v_tiene_cambios,'A') = 0 then
       DELETE FROM GE_SOL_ACT_PAR_CUENTAS WHERE NRO_SOLICITUD = p_nro_solicitud;
     end if;
     --
     COMMIT;
     --
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
       raise_application_error(-20011, 'Error: Eli_Solicitud. '||sqlerrm);
  END pr_eli_solicitud;


  /*
  Retorna true si la solicitud cambios ya registrados (Insercion, Modificacio, Eliminacion)
  en alguna de las tablas
  */

  FUNCTION fu_tie_modificaciones(p_nro_solicitud in number) return varchar2
   IS

     cursor ver_personas is
       select cod_persona, nro_solicitud, tip_modificacion
         from GE_SOL_ACT_PERSONAS
       where nro_solicitud =p_nro_solicitud;


       cursor ver_direcciones is
       select cod_persona, nro_solicitud, tip_modificacion
         from GE_SOL_ACT_DIRECCIONES
       where nro_solicitud =p_nro_solicitud;

       cursor ver_telefonos is
       select cod_persona, nro_solicitud, tip_modificacion
         from GE_SOL_ACT_TELEFONOS
       where nro_solicitud =p_nro_solicitud;

       cursor ver_mails is
       select cod_persona, nro_solicitud, tip_modificacion
         from GE_SOL_ACT_MAILS
       where nro_solicitud =p_nro_solicitud;

       cursor ver_dir_envios is
       select cod_persona, nro_solicitud, tip_modificacion
         from GE_SOL_ACT_DIR_ENVIOS
       where nro_solicitud =p_nro_solicitud;

       cursor ver_par_cuentas is
       select cod_persona, nro_solicitud, tip_modificacion
         from GE_SOL_ACT_PAR_CUENTAS
       where nro_solicitud =p_nro_solicitud;

    v_tiene varchar2(8):= NULL;

   BEGIN
    -- verifica si hay cambios en personas
     For i in ver_personas Loop
      	If i.TIP_MODIFICACION <> 'N'Then
  		     v_tiene:='P';
  		     exit;
  	    end if;
     End Loop;

  -- verifica si hay cambios en direcciones
       For i in ver_direcciones  Loop
          If i.TIP_MODIFICACION <> 'N'Then
            v_tiene:=v_tiene||'D';
            exit;
          end if;
       end loop;
     -- verifica si hay cambios en telefonos
      for i in ver_telefonos  Loop
        If i.TIP_MODIFICACION <> 'N'Then
          v_tiene:=v_tiene||'T';
          exit;
        end if;
      End Loop;
     -- verifica si hay cambios en MAILS
       for i in ver_mails Loop
         If i.TIP_MODIFICACION <> 'N'Then
            v_tiene:=v_tiene||'M';
           exit;
         end if;
       End Loop;
     -- verifica si hay cambios en DIR ENVIOS
      for i in ver_dir_envios Loop
        If i.TIP_MODIFICACION <> 'N'Then
          v_tiene:=v_tiene||'E';
          exit;
        end if;
  	  End Loop;
      -- verifica si hay cambios en PARAMETROS ADICIONALES
      for i in ver_par_cuentas loop
        if i.tip_modificacion <> 'N' then
          v_tiene := v_tiene||'A';
          exit;
        end if;
      end loop;

   -- formato de retorno v_tiene := 'PDTMEA' = Personas,Direcciones,Telefonos,Mails,Dir.Envios,AdicionalesdeCtas
   return NVL(v_tiene,'N');

  END fu_tie_modificaciones;

  /*
  Genera el circuito o workflow para la verificacion de los cambios
  Cambia el estdo de las tablas a PVE. Pend de verificacion
  Retorna el codigo del circuito generado.
  */
  function fu_gen_circuito(p_cod_persona in varchar2, p_nro_solicitud in number) return number is
    v_cod_circuito wf_circuitos.cod_circuito%Type;
    v_cod_error        NUMBER;
    v_msg_error varchar2(1000);
    update_exp EXCEPTION;
    PRAGMA EXCEPTION_INIT( update_exp, -20001 );
    begin

       v_cod_error := paw_cir.FU_INI_CIRCUITO(g_cod_tip_circuito,p_nro_solicitud,p_cod_persona);
       IF v_cod_error <> 0 THEN
          raise_application_error(-20067, 'Error al generar Circuito. ' || SQLERRM);
       else
          -- cambio el estado a Pend. de Verificacion.
          pr_act_est_solicitud(p_nro_solicitud,'PVE',v_msg_error);  -- estado al que va actualizar
          --
         if v_msg_error is not null then
            raise update_exp;
         end if;
         -- obtengo el numero del WorkFlow generado
         select cod_circuito into v_cod_circuito
         from wf_circuitos w
           where w.cod_tip_circuito =g_cod_tip_circuito
           and w.referencia= p_nro_solicitud
           and w.estado = 'E'
           and w.cod_persona = p_cod_persona
           and trunc(w.fec_insercion) = trunc(sysdate)
           and w.cod_circuito = (select max(cod_circuito)
                                   from wf_circuitos wc
                                  where wc.cod_tip_circuito = g_cod_tip_circuito
                                   and wc.referencia= p_nro_solicitud
                                   and wc.cod_persona = p_cod_persona);
           --
         return v_cod_circuito;
       end if;
       return 0;
     exception
        when update_exp then
          raise_application_error( -20001, 'Al cambiar estado. '||v_msg_error );
        when others then
          raise_application_error( -20000, sqlerrm );
    end;

  -- eliminar registros insertados inicialmente y que no fueron modificados
  -- se ejecuta cuando se solicita aprobacion de la solicitud, de manera que en la solicitud quedan solo los
  -- registros modificados por el usuario.
  procedure pr_eli_reg_solicitud(p_cod_persona in varchar2, p_nro_solicitud in number, p_msg_error out varchar2) is
    v_lugar varchar2(1000);
   begin

         v_lugar :='Eliminando direcciones.';
         delete from ge_sol_act_direcciones a
         where a.nro_solicitud   = p_nro_solicitud
           and a.cod_persona     = p_cod_persona
           and a.tip_modificacion= 'N';  -- registros no modificados

         v_lugar :='Eliminado teléfonos.';
         delete from  ge_sol_act_telefonos a
         where a.nro_solicitud   = p_nro_solicitud
           and a.cod_persona     = p_cod_persona
           and a.tip_modificacion= 'N';  -- registros no modificados

         v_lugar :='Eliminando mails.';
         delete from ge_sol_act_mails a
         where a.nro_solicitud   = p_nro_solicitud
           and a.cod_persona     = p_cod_persona
           and a.tip_modificacion= 'N';  -- registros no modificados

         v_lugar :='Eliminando datos personales.';
         delete from ge_sol_act_personas a
          where a.nro_solicitud  = p_nro_solicitud
           and a.cod_persona     = p_cod_persona
           and a.tip_modificacion= 'N';  -- registros no modificados

         v_lugar :='Eliminando Dir.Envios.';
         delete from ge_sol_act_dir_envios a
         where a.nro_solicitud   = p_nro_solicitud
           and a.cod_persona     = p_cod_persona
           and a.tip_modificacion= 'N';  -- registros no modificados

         v_lugar :='Eliminando Par.Adicionales.';
         delete from ge_sol_act_par_cuentas a
         where a.nro_solicitud   = p_nro_solicitud
           and a.cod_persona     = p_cod_persona
           and a.tip_modificacion= 'N';  -- registros no modificados
   exception
     when others then
         p_msg_error :=  'Error: '||v_lugar ||'-'||sqlerrm;
   end;

  /*
   Ejecutado desde la funcion fu_gen_circuito cuando la solicitud cambia de estado a PVE y desde
   el worfklow cuando se Rechaza o Cancela la Solicitud.
   Recibe como parametro el numero de solicitud y el codigo de estado al que se tiene que actualizar las tablas
  */
  PROCEDURE pr_act_est_solicitud(p_nro_solicitud in number,p_cod_estado in varchar2, p_msg in out varchar2) is
    v_lugar varchar2(1000);
    v_mensaje varchar2(200) := p_msg;
    v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);

   begin
       --
        p_msg := null;
       if p_cod_estado <> ('APR') then
            v_lugar :='Actualizar Estado - Act.Datos';
            update ge_sol_act_datos a
              set a.est_anterior   = a.estado,
                  a.estado         = p_cod_estado,
                  a.fec_cam_estado = v_fec_actual,
                  a.mot_rechazo    = v_mensaje
            where a.nro_solicitud = p_nro_solicitud;
       else
            update ge_sol_act_datos a
              set a.est_anterior       = a.estado,
                  a.estado             = p_cod_estado,
                  a.fec_cam_estado     = v_fec_actual,
                  a.cod_usu_aprobacion = upper(user),
                  a.cod_ofi_aprobacion = fug_obt_ofi_usuario(upper(user)),
                  a.observacion        = v_mensaje
            where a.nro_solicitud = p_nro_solicitud;
       end if;

   exception
     when others then
         pag_sad.g_cod_error := 5;
         pag_sad.g_msg_error := 'Error al ' ||v_lugar|| sqlerrm;
         p_msg :=  pag_sad.g_msg_error;
   END pr_act_est_solicitud;

 /*
 Procedimiento ejecutado desde el Workflow - Tip Circuito 99 cuando se aprueba la solicitud.
 Actualiza las tablas ba_* segun el dato modificado
 Actualiza las tablas ge_sol_act_* al estado aprobado
 Envia notificacion al cliente por cambio de mail
 */

 PROCEDURE pr_apr_solicitud(p_nro_solicitud in number, p_cod_persona in varchar2, p_msg_error in out varchar2)
   IS

   CURSOR personas is
     SELECT nro_solicitud, cod_persona, tipo,
            cod_tip_documento, nro_documento, fec_vto_documento, cod_pai_documento,
            dir_correo, pri_nombre, pri_apellido, seg_nombre, seg_apellido, fec_nacimiento,
            raz_social, nom_comercial, fec_apertura, naturaleza, tip_modificacion,est_civil
       FROM ge_sol_act_personas
      WHERE nro_solicitud = p_nro_solicitud
       AND cod_persona = p_cod_persona
       AND tip_modificacion in ('I','E','M')  -- Insercion, Eliminacion, Modificacion
       order by decode(tip_modificacion,'E', 1, 'M', 2, 'I', 3, 4); -- ordenamos para que 1-Elimine;2-Modif y 3-Inserte

    CURSOR direcciones is
      SELECT nro_solicitud, cod_persona,cod_direccion,tipo,principal,
            direccion, numero,  dir_lateral,   edificio,   piso,   departamento, cod_pais,
            cod_ciudad, cod_barrio, cod_postal, observacion, tip_modificacion
       FROM Ge_Sol_Act_Direcciones
      WHERE nro_solicitud = p_nro_solicitud
       AND cod_persona = p_cod_persona
       AND tip_modificacion in ('I','E','M') -- Insercion, Eliminacion, Modificacion
       order by decode(tip_modificacion,'E', 1, 'M', 2, 'I', 3, 4); -- ordenamos para que 1-Elimine;2-Modif y 3-Inserte

     CURSOR telefonos is
       SELECT nro_solicitud, cod_persona, cod_telefono, tipo,
              tip_linea, telefono, principal, area, interno, observacion, tip_modificacion
        FROM Ge_Sol_Act_Telefonos
       WHERE nro_solicitud = p_nro_solicitud
         AND cod_persona = p_cod_persona
         AND tip_modificacion in ('I','E','M') -- Insercion, Eliminacion, Modificacion
         order by decode(tip_modificacion,'E', 1, 'M', 2, 'I', 3, 4); -- ordenamos para que 1-Elimine;2-Modif y 3-Inserte

     CURSOR mails is
       SELECT nro_solicitud, cod_persona, tipo, dir_correo,
              principal, observacion, tip_modificacion, dir_correo_ant, tipo_ant
        FROM Ge_Sol_Act_mails
       WHERE nro_solicitud = p_nro_solicitud
         AND cod_persona = p_cod_persona
         AND tip_modificacion in ('I','E','M') -- Insercion, Eliminacion, Modificacion
         order by decode(tip_modificacion,'E', 1, 'M', 2, 'I', 3, 4); -- ordenamos para que 1-Elimine;2-Modif y 3-Inserte

     CURSOR dir_envios is
       SELECT nro_solicitud, cod_persona, tip_envio,
              referencia, nro_cuenta, observacion, tip_modificacion,nro_cuenta_ant
        FROM Ge_Sol_Act_Dir_Envios
       WHERE nro_solicitud = p_nro_solicitud
         AND cod_persona = p_cod_persona
         AND tip_modificacion in ('I','E','M') -- Insercion, Eliminacion, Modificacion
         order by decode(tip_modificacion,'E', 1, 'M', 2, 'I', 3, 4); -- ordenamos para que 1-Elimine;2-Modif y 3-Inserte


     CURSOR adicionales is
       SELECT nro_solicitud, cod_persona, parametro,
              nro_cuenta, valor, tip_modificacion
        FROM Ge_Sol_Act_Par_Cuentas
       WHERE nro_solicitud = p_nro_solicitud
         AND cod_persona = p_cod_persona
         AND tip_modificacion in ('I','E','M') -- Insercion, Eliminacion, Modificacion
         order by decode(tip_modificacion,'E', 1, 'M', 2, 'I', 3, 4); -- ordenamos para que 1-Elimine;2-Modif y 3-Inserte
  -- variables
  v_lugar varchar2(1000);
  rg_personas ba_personas%rowtype;
  rg_per_fisicas ba_per_fisicas%rowtype;
  rg_per_juridicas ba_per_juridicas%rowtype;
  rg_per_direcciones ba_direcciones%rowtype;
  rg_per_telefonos ba_telefonos%rowtype;
  rg_per_mails ba_mails%rowtype;
  rg_per_dir_envios ge_dir_envios%rowtype;
  rg_cta_adicionales ge_cta_dat_adicionales%rowtype;
  v_dir_mail_new ba_personas.dir_correo%type;
  v_dir_mail_old ba_personas.dir_correo%type;
  v_cod_programa ba_programas.cod_programa%Type;
  v_cam_persona varchar2(1):='N';
  v_cam_per_fisica varchar2(1):='N';
  v_error EXCEPTION;
  PRAGMA EXCEPTION_INIT( v_error, -20100 );
 -- actualiza a M - Modificado el estado de la verificacion en la tabla
 -- emulando lo realizado en ERCAPERS
 procedure lp_act_per_validaciones is
   v_fec_ver_persona ba_per_validaciones.fec_ver_persona%type;
   v_est_dat_persona ba_per_validaciones.est_dat_persona%type;
  BEGIN
     begin
      SELECT fec_ver_persona, est_dat_persona
        INTO v_fec_ver_persona, v_est_dat_persona
      FROM ba_per_validaciones
       WHERE cod_persona = p_cod_persona;
    exception
      when no_data_found then
         v_fec_ver_persona := null;
      when too_many_rows then
        SELECT fec_ver_persona, est_dat_persona
           INTO v_fec_ver_persona, v_est_dat_persona
         FROM ba_per_validaciones
        WHERE cod_persona = p_cod_persona
          and fec_ver_persona = (select max(fec_ver_persona) from ba_per_validaciones
                                   WHERE cod_persona = p_cod_persona);
      when others then
         v_fec_ver_persona := null;
     end;
     -- si no fue verificado y se modifico algun dato de la persona, cambia el estado a M- Modificado
     -- emula el comportamiento de ERCAPERS para que se verifique los datos.
     IF v_fec_ver_persona is not null and (v_cam_persona = 'S' OR v_cam_per_fisica = 'S')  then
        if trunc(v_fec_ver_persona) <> trunc(sysdate) and v_est_dat_persona <> 'V' then
            UPDATE ba_per_validaciones
               SET est_dat_persona = 'M'
             WHERE cod_persona = p_cod_persona;
         end if;
      END IF;
 exception
    when others then
      null;
 end;
 ------------------------------------------------------------------------------------------------------
 ------------------------------------------------------------------------------------------------------
 BEGIN
       -- recorrer las tablas y segun el tipo de modificacion actualizr los campos, insertar o eliminar en las tablas ba_
        -- actualizar estado de las tablas ge_sol_act
        -- actualizar autorizador.
        -- por modificacion de correo notificar al cliente

    begin
      v_lugar:= 'Aprob.Solicitud.';

      pag_sad.pr_act_est_solicitud(p_nro_solicitud,'APR',p_msg_error);
      if p_msg_error is not null then
         pag_sad.g_cod_error := 10;
         pag_sad.g_msg_error := 'No se ha podido ' || p_msg_error;
         raise v_error; 
      end if;
    exception
        when others then
          pag_sad.g_cod_error := 11;
          pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
          raise v_error;
    end;
    --
    ---
    v_cod_programa := pae_cnf.FU_OBT_COD_PROGRAMA;
    pae_cnf.G_PROGRAMA := 'PAG_SAD';
    ---

    v_lugar:= 'Carga de datos originales de Personas'  ;
    begin
      select *
        into rg_personas
        from ba_personas
       where cod_persona = p_cod_persona;
    exception
      when no_data_found then
        pae_cnf.G_PROGRAMA :=v_cod_programa;
        raise_application_error(-20015, 'Error: '||v_lugar || '-' || sqlerrm);
    end;

    if rg_personas.tipo = 'F' then
      begin
        select *
          into rg_per_fisicas
          from ba_per_fisicas
         where cod_persona = p_cod_persona;
      exception
        when no_data_found then
          rg_per_fisicas := null;
      end;
    else
      begin
        select *
          into rg_per_juridicas
          from ba_per_juridicas
         where cod_persona = p_cod_persona;
      exception
        when no_data_found then
          rg_per_juridicas := null;
      end;
    end if;
    --
    v_dir_mail_new := null;
    v_dir_mail_old := null;
    --
    for x in personas loop
       begin
         -- si tipo persona es F entonces busca en ba_per_fisicas.
         if x.tip_modificacion ='M' then
            if x.tipo = 'F' then    -- si es persona fisica
              v_lugar:= 'Act.Fecha Nac.';
              if (x.fec_nacimiento <> rg_per_fisicas.fec_nacimiento) or
                  (rg_per_fisicas.fec_nacimiento is null and x.fec_nacimiento is not null)  then
                  begin
                    update ba_per_fisicas
                      set fec_nacimiento = x.fec_nacimiento
                    where cod_persona = p_cod_persona;
                  exception
                    when others then
                       pae_cnf.G_PROGRAMA :=v_cod_programa;
                       pag_sad.g_cod_error := 12;
                       pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                       raise v_error;
                  end;
                  v_cam_per_fisica :='S';
              end if; --            
              
              v_lugar:= 'Act.Primer Nombre';
              if nvl(x.pri_nombre,'z') <> nvl(rg_per_fisicas.pri_nombre,'z') then
                begin
                  update ba_per_fisicas
                    set pri_nombre = x.pri_nombre
                  where cod_persona = p_cod_persona;
                exception
                  when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                       pag_sad.g_cod_error := 13;
                       pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                       raise v_error;

                end;
                  v_cam_per_fisica :='S';
               end if; --
               v_lugar:= 'Act.Segundo Nombre';
               if nvl(x.seg_nombre,'z') <> nvl(rg_per_fisicas.seg_nombre,'z') then
                begin
                  update ba_per_fisicas
                    set seg_nombre = x.seg_nombre
                  where cod_persona = p_cod_persona;
                exception
                  when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 14;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                end;
                  v_cam_per_fisica :='S';
               end if; --
               v_lugar:= 'Act.Primer Apellido';
               if nvl(x.pri_apellido,'z') <> nvl(rg_per_fisicas.pri_apellido,'z') then
                begin
                  update ba_per_fisicas
                    set pri_apellido = x.pri_apellido
                  where cod_persona = p_cod_persona;
                exception
                  when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 15;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                end;
                  v_cam_per_fisica :='S';
               end if; --
               v_lugar:= 'Act.Segundo Apellido';
               if nvl(x.seg_apellido,'z') <> nvl(rg_per_fisicas.seg_apellido,'z') then
                begin
                  update ba_per_fisicas
                    set seg_apellido = x.seg_apellido
                  where cod_persona = p_cod_persona;
                exception
                  when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 16;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                end;
                  v_cam_per_fisica :='S';
               end if; --
               
               /* Evo-BSEVOCORE-511 */
              v_lugar:= 'Act.est_civil';
              if (x.est_civil <> rg_per_fisicas.est_civil) or
                  (rg_per_fisicas.est_civil is null and x.est_civil is not null)  then
                  begin
                    update ba_per_fisicas
                      set est_civil = x.est_civil
                    where cod_persona = p_cod_persona;
                  exception
                    when others then
                       pae_cnf.G_PROGRAMA :=v_cod_programa;
                       pag_sad.g_cod_error := 70;
                       pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                       raise v_error;
                  end;
                  v_cam_per_fisica :='S';
              end if; --
              /**/ 
               
               
             else    -- si es persona juridica
               v_lugar:= 'Act.Razon Social.';
               if nvl(x.raz_social,'z') <> nvl(rg_per_juridicas.raz_social,'z') then
                  begin
                     update ba_per_juridicas
                       set raz_social = x.raz_social
                     where cod_persona = p_cod_persona;
                  exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 17;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                  end;
               end if; --
               v_lugar:= 'Act.Nom_Comercial.';
               if nvl(x.nom_comercial,'z') <> nvl(rg_per_juridicas.nom_comercial,'z') then
                  begin
                     update ba_per_juridicas
                       set nom_comercial = x.nom_comercial
                     where cod_persona = p_cod_persona;
                  exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 18;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                  end;
               end if; --
               v_lugar:= 'Act.Fec_Apertura.';
               if (x.fec_apertura <> rg_per_juridicas.fec_apertura) or
                  (rg_per_juridicas.fec_apertura is null and x.fec_apertura is not null)  then
                  begin
                     update ba_per_juridicas
                       set fec_apertura = x.fec_apertura
                     where cod_persona = p_cod_persona;
                  exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 19;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                  end;
               end if; --
               v_lugar:= 'Act.Naturaleza.';
               if nvl(x.naturaleza,'z') <> nvl(rg_per_juridicas.naturaleza,'z') then
                  begin
                     update ba_per_juridicas
                       set naturaleza = x.naturaleza
                     where cod_persona = p_cod_persona;
                  exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 20;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                  end;
               end if; --
             end if;  -- fin tip_persona

             -- update ba_personas
             v_lugar:='Act.Nro.Documento y Tipo Doc.';
             -- actualizamos los dos datos de una vez para evitar problemas de validaciones en los triggers de ba_personas
             if nvl(x.nro_documento,'z') <> nvl(rg_personas.nro_documento,'z') and
                nvl(x.cod_tip_documento, -1) <> nvl(rg_personas.cod_tip_documento,-1) then
                begin
                  update ba_personas
                    set nro_documento = x.nro_documento,
                        cod_tip_documento = x.cod_tip_documento
                  where cod_persona  = p_cod_persona;
                exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 21;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                end;
                v_cam_persona :='S';
             -- solo se modifico el numero de docuento   
             elsif nvl(x.nro_documento,'z') <> nvl(rg_personas.nro_documento,'z') and
                   nvl(x.cod_tip_documento, -1) = nvl(rg_personas.cod_tip_documento,-1)then
                  v_lugar:='Act.N° Documento.';     
                  begin
                     update ba_personas
                       set nro_documento = x.nro_documento
                     where cod_persona  = p_cod_persona;
                  exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 22;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
                  end;
                v_cam_persona :='S';
             else -- se modifico el tipo de documento
                 v_lugar:='Act.Tipo Documento.';
                 if nvl(x.cod_tip_documento, -1) <> nvl(rg_personas.cod_tip_documento,-1) then
                   begin
                     update ba_personas
                       set cod_tip_documento = x.cod_tip_documento
                     where cod_persona  = p_cod_persona;
                 exception
                        when others then
                          pae_cnf.G_PROGRAMA :=v_cod_programa;
                          pag_sad.g_cod_error := 23;
                          pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                          raise v_error;
                      end;
                    v_cam_persona :='S';
                 end if; --
              end if;   
             v_lugar:='Act.Fec Vto.Documento.';
             if (x.fec_vto_documento <> rg_personas.fec_vto_documento) or
                (rg_personas.fec_vto_documento is null and x.fec_vto_documento is not null) then
               begin
                 update ba_personas
                   set fec_vto_documento = x.fec_vto_documento
                 where cod_persona  = p_cod_persona;
               exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 24;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
               end;
                 v_cam_persona :='S';
             end if; --
             v_lugar:='Act.Cod.Pais Documento.';
             if nvl(x.cod_pai_documento,-1) <> nvl(rg_personas.cod_pai_documento,-1) then
               begin
                 update ba_personas
                   set cod_pai_documento = x.cod_pai_documento
                 where cod_persona  = p_cod_persona;
               exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 25;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
               end;
               v_cam_persona :='S';
             end if; --
             v_lugar:='Act.Dir.Correo';
             if nvl(x.dir_correo,'z') <> nvl(rg_personas.dir_correo,'z') then
               --
               v_dir_mail_old := rg_personas.dir_correo;
               v_dir_mail_new := x.dir_correo;
               --
               begin
                 update ba_personas
                   set dir_correo = x.dir_correo
                 where cod_persona  = p_cod_persona;
               exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 26;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
               end;
               v_cam_persona :='S';
             end if; --
          end if; -- fin tip_modificacion
       end;
     end loop;


     -- direcciones
     for i in direcciones loop
       -- modificaciones
       if i.tip_modificacion ='M' then
         v_lugar:='Al recuperar datos Direcciones.'||i.cod_persona;
          -- obtengo los datos originales de la direccion en cuestion
          begin
            select *
              into rg_per_direcciones
              from ba_direcciones
             where cod_persona = p_cod_persona
              and  cod_direccion = i.cod_direccion;
          exception
            when no_data_found then
              rg_per_direcciones := null;
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              pag_sad.g_cod_error := 27;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
          end;

          v_lugar:='Act.Tipo Dirección.';
          if nvl(i.tipo,'x') <> nvl(rg_per_direcciones.tipo,'x') then
             begin
                update ba_direcciones
                  set tipo = i.tipo
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
             exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 28;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Dir.Principal.';
          if nvl(i.principal,'N') <> nvl(rg_per_direcciones.principal,'N') then
            begin
                update ba_direcciones
                  set principal = i.principal
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 29;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Dirección.';
          if nvl(i.direccion,'xy') <> nvl(rg_per_direcciones.direccion,'xy') then
            begin
                update ba_direcciones
                  set direccion = i.direccion
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                  when others then
                    pae_cnf.G_PROGRAMA :=v_cod_programa;
                    pag_sad.g_cod_error := 30;
                    pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                    raise v_error;
             end;
          end if;
          v_lugar:='Act.Dir.Número.';
          if nvl(i.numero,'xy') <> nvl(rg_per_direcciones.numero,'xy') then
            begin
                update ba_direcciones
                  set numero = i.numero
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 31;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Dir.Lateral.';
          if nvl(i.dir_lateral,'xy') <> nvl(rg_per_direcciones.dir_lateral,'xy') then
            begin
                update ba_direcciones
                  set dir_lateral = i.dir_lateral
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 32;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;

          v_lugar:='Act.Departamento.';
          if nvl(i.departamento,'xy') <> nvl(rg_per_direcciones.departamento,'xy') then
            begin
                update ba_direcciones
                  set departamento = i.departamento
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 33;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;

          v_lugar:='Act.Piso.';
          if nvl(i.piso,'xy') <> nvl(rg_per_direcciones.piso,'xy') then
            begin
                update ba_direcciones
                  set piso = i.piso
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 34;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;

          v_lugar:='Act.Edificio.';
          if nvl(i.edificio,'xy') <> nvl(rg_per_direcciones.edificio,'xy') then
            begin
                update ba_direcciones
                  set edificio = i.edificio
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                       pae_cnf.G_PROGRAMA :=v_cod_programa;
                       pag_sad.g_cod_error := 35;
                       pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                       raise v_error;
             end;
          end if;
          v_lugar:='Act.Cod.Postal.';
          if nvl(i.cod_postal,'xy') <> nvl(rg_per_direcciones.cod_postal,'xy') then
            begin
                update ba_direcciones
                  set cod_postal = i.cod_postal
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 36;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;

          v_lugar:='Act.Obs.Direccion';
          if nvl(i.observacion,'xy') <> nvl(rg_per_direcciones.observacion,'xy') then
            begin
                update ba_direcciones
                  set observacion = i.observacion
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 36;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;

          v_lugar:='Act.Cod.Pais.';
          if nvl(i.cod_pais,-1) <> nvl(rg_per_direcciones.cod_pais,-1) then
            begin
                update ba_direcciones
                  set cod_pais = i.cod_pais
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 37;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;

          v_lugar:='Act.Cod.Ciudad.';
          if nvl(i.cod_ciudad,-1) <> nvl(rg_per_direcciones.cod_ciudad,-1) then
            begin
                update ba_direcciones
                  set cod_ciudad = i.cod_ciudad
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 38;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;

          v_lugar:='Act.Cod.Barrio.';
          if nvl(i.cod_barrio,-1) <> nvl(rg_per_direcciones.cod_barrio,-1) then
            begin
                update ba_direcciones
                  set cod_barrio = i.cod_barrio
                where cod_persona  = p_cod_persona
                  and cod_direccion = i.cod_direccion;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 39;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
       end if; -- fin tip_modificacion M
       -- inserciones
       if i.tip_modificacion ='I' then
         v_lugar:='Ins.Nueva.Dirección.';
         begin
           insert into ba_direcciones(cod_persona,cod_direccion,tipo,principal,direccion,cod_pais,cod_ciudad,cod_barrio,
                                       observacion,numero,departamento,piso,edificio,cod_postal,dir_lateral)
              values (i.cod_persona, i.cod_direccion, i.tipo, i.principal, i.direccion, i.cod_pais, i.cod_ciudad, i.cod_barrio,
                      i.observacion, i.numero, i.departamento, i.piso, i.edificio, i.cod_postal, i.dir_lateral);
         exception
              when others then
                pae_cnf.G_PROGRAMA :=v_cod_programa;
                pag_sad.g_cod_error := 40;
                pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                raise v_error;
         end;
       end if;  -- fin tip_modificacion Insert

       -- eliminaciones
       if i.tip_modificacion ='E' then
         v_lugar:='Elimina Dirección.';
         begin
           delete from ba_direcciones
             where cod_persona  = p_cod_persona
              and cod_direccion = i.cod_direccion;
         exception
              when others then
                pae_cnf.G_PROGRAMA :=v_cod_programa;
                pag_sad.g_cod_error := 41;
                pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                raise v_error;
         end;
       end if; -- fin tip_modificacion delete
     end loop;

     -- telefonos
     for a in telefonos loop
       if a.tip_modificacion ='M' then
         v_lugar:='Al recuperar datos Telefonos.'||a.cod_persona;
          begin
            select *
              into rg_per_telefonos
              from ba_telefonos
             where cod_persona = p_cod_persona
               and cod_telefono = a.cod_telefono;
          exception
            when no_data_found then
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              rg_per_telefonos := null;
              pag_sad.g_cod_error := 42;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
          end;
          v_lugar:='Act.Tipo.Telefono';
          if nvl(a.tipo,'y') <> nvl(rg_per_telefonos.tipo,'y') then
            begin
                update ba_telefonos
                  set tipo = a.tipo
                where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 43;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Tip.Linea';
          if nvl(a.tip_linea,'y') <> nvl(rg_per_telefonos.tip_linea,'y') then
            begin
                update ba_telefonos
                  set tip_linea = a.tip_linea
                where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 44;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Telefono';
          if nvl(a.telefono,'xy') <> nvl(rg_per_telefonos.telefono,'xy') then
            begin
                update ba_telefonos
                  set telefono = a.telefono
                where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 45;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Tel.Principal';
          if nvl(a.principal,'y') <> nvl(rg_per_telefonos.principal,'y') then
            begin
                update ba_telefonos
                  set principal = a.principal
                where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 46;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
           v_lugar:='Act.Area';
          if nvl(a.area,'y') <> nvl(rg_per_telefonos.area,'y') then
            begin
                update ba_telefonos
                  set area = a.area
                where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 47;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Interno';
          if nvl(a.interno,'y') <> nvl(rg_per_telefonos.interno,'y') then
            begin
                update ba_telefonos
                  set interno = a.interno
                where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 48;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
          v_lugar:='Act.Obs.Telefono';
          if nvl(a.observacion,'xyz') <> nvl(rg_per_telefonos.observacion,'xyz') then
            begin
                update ba_telefonos
                  set observacion = a.observacion
                where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
              exception
                    when others then
                      pae_cnf.G_PROGRAMA :=v_cod_programa;
                      pag_sad.g_cod_error := 49;
                      pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                      raise v_error;
             end;
          end if;
       end if; -- fin tip_modificacion M

       -- inserciones
       if a.tip_modificacion ='I' then
         v_lugar:='Insert Nuevo Telef.'||a.area||'-'||a.telefono;
         begin
             insert into ba_telefonos(cod_persona, tipo, tip_linea, telefono, principal, area,
                                      interno, observacion, cod_telefono)
                         values(a.cod_persona, a.tipo, a.tip_linea, a.telefono, a.principal, a.area,
                                a.interno,a.observacion, a.cod_telefono);
         exception
              when others then
                pae_cnf.G_PROGRAMA :=v_cod_programa;
                pag_sad.g_cod_error := 50;
                pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                raise v_error;
         end;
       end if; -- fin tip_modificacion I

       -- eliminaciones
       if a.tip_modificacion ='E' then
          v_lugar:='Eliminando Telef.'||a.area||'-'||a.telefono;
          begin
            delete from ba_telefonos
              where cod_persona  = p_cod_persona
                  and cod_telefono = a.cod_telefono;
          exception
              when others then
                pae_cnf.G_PROGRAMA :=v_cod_programa;
                pag_sad.g_cod_error := 51;
                pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                raise v_error;
         end;
       end if; -- fin tip_modificacion E
     end loop;

     -- mails
     for m in mails loop
       if m.tip_modificacion = 'M' then
         v_lugar:='Al recuperar datos Mails.'||m.cod_persona;
          begin
            select *
              into rg_per_mails
              from ba_mails
             where cod_persona = p_cod_persona
               and dir_correo = m.dir_correo_ant
               and tipo       = m.tipo_ant;
          exception
            when no_data_found then
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              rg_per_mails := null;
              pag_sad.g_cod_error := 52;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
          end;
          v_lugar:='Act.Tipo Mails.'||m.Dir_Correo;
          if nvl(m.tipo, 'x') <> nvl(rg_per_mails.tipo,'x') then
             begin
               update ba_mails
                 set tipo = m.tipo
               where cod_persona = m.cod_persona
                 and dir_correo = m.dir_correo_ant  -- en este campo se almacena el correo original
                 and tipo       = m.tipo_ant;        -- en este campo se almacena el tipo original
             exception
                 when others then
                   pae_cnf.G_PROGRAMA :=v_cod_programa;
                   pag_sad.g_cod_error := 53;
                   pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                   raise v_error;
             end;
          end if;
          v_lugar:='Act.DirCorreo-Mails.'||m.Dir_Correo;
          if nvl(m.dir_correo, 'xyz') <> nvl(rg_per_mails.dir_correo,'xyz') then
            -- si en ba_personas.dir_correo ya se registro cambio de email, prevalece ese cambio para la notif,
            if v_dir_mail_old is null and v_dir_mail_new is null then
              v_dir_mail_old := rg_per_mails.dir_correo;
              v_dir_mail_new := m.dir_correo;
            end if;
            --
             begin
               update ba_mails
                 set dir_correo = m.dir_correo
               where cod_persona = m.cod_persona
                 and dir_correo = m.dir_correo_ant  -- en este campo se almacena el correo original
                 and tipo       = m.tipo_ant;       -- en este campo se almacena el tipo original
             exception
                 when others then
                   pae_cnf.G_PROGRAMA :=v_cod_programa;
                   pag_sad.g_cod_error := 54;
                   pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                   raise v_error;
             end;
          end if;
          v_lugar:='Act.Principal-Mails.'||m.Dir_Correo;
          if nvl(m.principal, 'x') <> nvl(rg_per_mails.principal,'x') then
             begin
               update ba_mails
                 set principal = m.principal
               where cod_persona = m.cod_persona
                 and dir_correo = m.dir_correo_ant  -- en este campo se almacena el correo original
                 and tipo       = m.tipo_ant;       -- en este campo se almacena el tipo original
             exception
                 when others then
                   pae_cnf.G_PROGRAMA :=v_cod_programa;
                   pag_sad.g_cod_error := 55;
                   pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                   raise v_error;
             end;
          end if;
          v_lugar:='Act.Obs-Mails.'||m.Dir_Correo;
          if nvl(m.observacion, 'xyz') <> nvl(rg_per_mails.observacion,'xyz') then
             begin
               update ba_mails
                 set observacion = m.observacion
               where cod_persona = m.cod_persona
                 and dir_correo = m.dir_correo_ant  -- en este campo se almacena el correo original
                 and tipo       = m.tipo_ant;       -- en este campo se almacena el tipo original
             exception
                 when others then
                   pae_cnf.G_PROGRAMA :=v_cod_programa;
                   pag_sad.g_cod_error := 56;
                   pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                   raise v_error;
             end;
          end if;
       end if; -- fin tip_modificacion M
       -- insercion de nuevos mails
       if m.tip_modificacion ='I' then
         v_lugar:='Ins.nuevo Mail.'||m.Dir_Correo;
          begin
             insert into ba_mails(cod_persona, tipo, dir_correo ,principal, observacion)
                values (m.cod_persona, m.tipo, m.dir_correo, m.principal, m.observacion);
           exception
                 when others then
                   pae_cnf.G_PROGRAMA :=v_cod_programa;
                   pag_sad.g_cod_error := 57;
                   pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                   raise v_error;
          end;
       end if;  -- fin tip_modificacion I
       -- eliminacion de mail
       if m.tip_modificacion ='E' then
           v_lugar:='Eliminar Mail.'||m.Dir_Correo;
           begin
             delete from ba_mails
               where cod_persona = p_cod_persona
                 and dir_correo = m.dir_correo_ant
                 and tipo = m.tipo_ant;
           exception
                 when others then
                   pae_cnf.G_PROGRAMA :=v_cod_programa;
                   pag_sad.g_cod_error := 58;
                   pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                   raise v_error;
          end;
       end if;  -- fin tip_modificacion E
     end loop;  -- mails

     -- dir envios
     for e in dir_envios loop
       -- modificaciones
       if e.tip_modificacion ='M' then
         v_lugar:='Al recuperar datos Dir.Envios.'||e.nro_cuenta;
          begin
            select *
              into rg_per_dir_envios
              from ge_dir_envios
             where cod_persona = p_cod_persona
              and nvl(nro_cuenta,'X') = nvl(e.nro_cuenta_ant,'X');
          exception
            when no_data_found then
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              rg_per_dir_envios := null;
              pag_sad.g_cod_error := 59;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
          end;
          v_lugar:='Act.Tip.Envio.'||e.cod_persona||'-'||e.nro_cuenta;
          if e.tip_envio <>  rg_per_dir_envios.tip_envio then
            begin
                update ge_dir_envios
                   set tip_envio = e.tip_envio
                where cod_persona = p_cod_persona
                  and nvl(nro_cuenta,'X')  = nvl(e.nro_cuenta_ant,'X');
            exception
                when others then
                  pae_cnf.G_PROGRAMA :=v_cod_programa;
                  pag_sad.g_cod_error := 60;
                  pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                  raise v_error;
            end;
           end if;
           v_lugar:='Act.REFERENCIA.'||e.cod_persona||'-'||e.nro_cuenta;
           if nvl(e.referencia,'abc') <>  nvl(rg_per_dir_envios.referencia,'abc') then
              begin
                  update ge_dir_envios
                     set referencia = e.referencia
                  where cod_persona = p_cod_persona
                    and nvl(nro_cuenta,'X')  = nvl(e.nro_cuenta_ant,'X');
              exception
                  when others then
                    pae_cnf.G_PROGRAMA :=v_cod_programa;
                    pag_sad.g_cod_error := 61;
                    pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                    raise v_error;
              end;
            end if;
            v_lugar:='Act.Cuenta-DirEnvios.'||e.cod_persona||'-'||e.nro_cuenta;
            if nvl(e.nro_cuenta,'abc') <>  nvl(rg_per_dir_envios.nro_cuenta,'abc') then
              begin
                  update ge_dir_envios
                     set nro_cuenta = e.nro_cuenta
                  where cod_persona = p_cod_persona
                    and nvl(nro_cuenta,'X')  = nvl(e.nro_cuenta_ant,'X');
              exception
                  when others then
                    pae_cnf.G_PROGRAMA :=v_cod_programa;
                    pag_sad.g_cod_error := 62;
                    pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                    raise v_error;
              end;
            end if;
             v_lugar:='Act.Obs.DirEnvios.'||e.cod_persona||'-'||e.nro_cuenta;
            if nvl(e.observacion,'abc') <>  nvl(rg_per_dir_envios.observacion,'abc') then
              begin
                  update ge_dir_envios
                     set observacion = e.observacion
                  where cod_persona  = p_cod_persona
                    and nvl(nro_cuenta,'X')   = nvl(e.nro_cuenta_ant,'X');
              exception
                  when others then
                    pae_cnf.G_PROGRAMA :=v_cod_programa;
                    pag_sad.g_cod_error := 63;
                    pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                    raise v_error;
              end;
            end if;
       end if; -- fin tip_modificacion M
       -- inserciones nuevos dir envios
       if e.tip_modificacion ='I' then
          v_lugar:='Ins.DirEnvios.'||e.cod_persona||'-'||e.nro_cuenta;
         begin
           insert into ge_dir_envios(cod_persona, tip_envio, referencia, nro_cuenta, observacion)
                   values (e.cod_persona, e.tip_envio, e.referencia, e.nro_cuenta, e.observacion);
         exception
            when others then
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              pag_sad.g_cod_error := 64;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
         end;
       end if; -- fin tip_modificacion I
       -- eliminaciones
       if e.tip_modificacion ='E' then
          v_lugar:='Eli.DirEnvios.'||e.cod_persona||'-'||e.nro_cuenta;
          begin
            delete from ge_dir_envios
              where cod_persona = p_cod_persona
                and nvl(nro_cuenta,'X') = nvl(e.nro_cuenta_ant, 'X');
            exception
            when others then
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              pag_sad.g_cod_error := 65;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
          end;
       end if; -- fin tip_modificacion E
     end loop;  -- dir envios

     --parametros adicionales de cuenta
     for adi in adicionales loop
       -- modificaciones
       if adi.tip_modificacion ='M' then
          v_lugar:='Al recuperar datos Par.Adi.Cta.'||adi.nro_cuenta;
           begin
             select * into rg_cta_adicionales
              from ge_cta_dat_adicionales ab
                where ab.nro_cuenta = adi.nro_cuenta
                  and ab.parametro = adi.parametro;
           exception
             when no_Data_found then
               pae_cnf.G_PROGRAMA :=v_cod_programa;
               rg_cta_adicionales := null;
               pag_sad.g_cod_error := 66;
               pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
               raise v_error;
           end;

           v_lugar:='Act.Val.Parametro.Cta.'||adi.nro_cuenta;
            if nvl(adi.valor,'abc') <>  nvl(rg_cta_adicionales.val_parametro ,'abc') then
              begin
                  update ge_cta_dat_adicionales
                     set val_parametro = adi.valor
                  where nro_cuenta = adi.nro_cuenta
                    and parametro  = adi.parametro;
              exception
                  when others then
                    pae_cnf.G_PROGRAMA :=v_cod_programa;
                    pag_sad.g_cod_error := 66;
                    pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
                    raise v_error;
              end;
            end if;
       end if;
       --inserciones
       if adi.tip_modificacion ='I' then
         v_lugar:='Ins.Parametro.Adi.Cta.'||adi.nro_cuenta;
         begin
           insert into ge_cta_dat_adicionales(nro_cuenta,parametro,val_parametro)
           values (adi.nro_cuenta, adi.parametro, adi.valor);
         exception
            when others then
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              pag_sad.g_cod_error := 67;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
         end;
       end if;
       -- eliminaciones
       if adi.tip_modificacion ='E' then
         v_lugar:='Eli.Parametro.Adi.Cta.'||adi.nro_cuenta;
         begin
           delete from ge_cta_dat_adicionales
            where nro_cuenta = adi.nro_cuenta
              and parametro  = adi.parametro;
         exception
            when others then
              pae_cnf.G_PROGRAMA :=v_cod_programa;
              pag_sad.g_cod_error := 68;
              pag_sad.g_msg_error := 'Error en ' ||v_lugar|| sqlerrm;
              raise v_error;
         end;
       end if;
     end loop;

   -- setamos nuevamente a su valor anterior
   pae_cnf.G_PROGRAMA :=v_cod_programa;
   --
   -- actualiza el campo de ba_per_Validaciones si hubo cambios en personas.
   lp_act_per_validaciones;
   --
   -- eliminamos registros no modificados de la solicitud aprobada.
   pag_sad.pr_eli_reg_solicitud(p_cod_persona,p_nro_solicitud,p_msg_error);
   --
   -- si no hubo error hasta aqui invocamos al procedimiento que envia la notificacion.
   if v_dir_mail_new is not null or v_dir_mail_old is not null then
     begin
       pag_sad.pr_env_notificacion(p_cod_persona,v_dir_mail_old, v_dir_mail_new);
     exception
       when others then
          pae_cnf.G_PROGRAMA :=v_cod_programa;
          null;  -- si hubo error en la notificacion igual se continua con el commit.
      end;
    end if;
    --
  EXCEPTION
    WHEN V_ERROR THEN
       pae_cnf.G_PROGRAMA :=v_cod_programa;
       p_msg_error:= pag_sad.g_msg_error;
    WHEN OTHERS THEN
       pae_cnf.G_PROGRAMA :=v_cod_programa;
        p_msg_error:='Error: '||v_lugar||'-'||sqlerrm;
       --raise_application_error( -20100,'Error: '||p_msg_error);
  END pr_apr_solicitud;
  ---

  -- notificacion por nuevo correo registrado o cambio de direccion de correo.
  procedure pr_env_notificacion(p_cod_persona in varchar2, p_dir_correo_ant in varchar2, p_dir_correo_new in varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION;

   v_mje_mail       LONG;
    v_conn           utl_smtp.connection;
    v_texto          varchar2(5000);
    v_texto_detalle  varchar2(32000) := null;
    v_membrete LONG := fug_gen_template('M');
    V_FIN      LONG := fug_gen_template('F');
    V_PIE      LONG := fug_gen_template('P');
    v_asunto           varchar2(100);
    v_det_error        ge_log_mail.det_error%type;
    v_hor_inicio       varchar2(10);

   begin
        v_asunto := 'Notificación de actualización de datos.';
        v_hor_inicio := to_char(sysdate,'hh24:mi:ss');


        v_texto := '<br><br>
                   <br><br>
                     Estimado cliente: '||upper(fue_obt_nom_persona(P_COD_PERSONA))||'
                   <br><br>
                     Le informamos que registramos las siguientes actualizaciones de sus datos.
                   <br><br>
                     Fecha: '||pag_cal.FU_OBT_FEC_ACTUAL(1)||'
                   <br><br>
                     Direccion de correo anterior: '||p_dir_correo_ant||'
                   <br><br>
                     Nueva direccion de correo: '||p_dir_correo_new||'
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';

                    v_mje_mail := v_membrete||v_texto||V_FIN||V_PIE;
                    -- se notifica al anterior
                    if p_dir_correo_ant is not null then
                       v_det_error:= null;
                       BEGIN
                        v_conn     := it_mail.begin_mail(fug_obt_pardinamico('CAN_MAR_DIR_MAIL'),
                                                         p_dir_correo_ant,
                                                         v_asunto,
                                                         IT_MAIL.MULTIPART_MIME_TYPE);
                        it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                        it_mail.write_text(v_conn, v_texto_detalle);
                        it_mail.end_mail(v_conn);
                      EXCEPTION
                        when utl_smtp.transient_error  or utl_smtp.permanent_error then
                          begin
                              utl_smtp.quit(v_conn);
                          exception
                            when utl_smtp.transient_error or
                                 utl_smtp.permanent_error then
                            null;
                          end;
                          v_det_error := substr(sqlerrm,1,4000);
                        when others then
                          begin
                            utl_smtp.quit(v_conn);
                          exception
                            when utl_smtp.transient_error or
                                 utl_smtp.permanent_error then
                            null;
                          end;
                          v_det_error := substr(sqlerrm,1,4000);
                       END;

                       IF v_det_error IS NOT NULL THEN
                            insert into ge_log_mail
                             (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
                            values
                             (sysdate, p_cod_persona, p_dir_correo_ant, v_asunto, v_det_error, null, v_hor_inicio, to_char(sysdate,'hh24:mi:ss'));
                      end if;
                  end if;

                  -- se notifica al correo nuevo
                    if p_dir_correo_new is not null then
                      v_det_error := null;
                       BEGIN
                        v_conn     := it_mail.begin_mail(fug_obt_pardinamico('CAN_MAR_DIR_MAIL'),
                                                         p_dir_correo_new,
                                                         v_asunto,
                                                         IT_MAIL.MULTIPART_MIME_TYPE);
                        it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                        it_mail.write_text(v_conn, v_texto_detalle);
                        it_mail.end_mail(v_conn);
                      EXCEPTION
                        when utl_smtp.transient_error  or utl_smtp.permanent_error then
                          begin
                              utl_smtp.quit(v_conn);
                          exception
                            when utl_smtp.transient_error or
                                 utl_smtp.permanent_error then
                            null;
                          end;
                          v_det_error := substr(sqlerrm,1,4000);
                        when others then
                          begin
                            utl_smtp.quit(v_conn);
                          exception
                            when utl_smtp.transient_error or
                                 utl_smtp.permanent_error then
                            null;
                          end;
                          v_det_error := substr(sqlerrm,1,4000);
                       END;

                       IF v_det_error IS NOT NULL THEN
                            insert into ge_log_mail
                             (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
                            values
                             (sysdate, p_cod_persona, p_dir_correo_new, v_asunto, v_det_error, null, v_hor_inicio, to_char(sysdate,'hh24:mi:ss'));
                      end if;
                  end if;
                  commit;
  exception
    when others then
      insert into ge_log_mail
         (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
        values
         (sysdate, p_cod_persona, p_dir_correo_new, v_asunto, nvl(v_det_error,'Error en la notificacion'), null, v_hor_inicio, to_char(sysdate,'hh24:mi:ss'));
      commit;
  end pr_env_notificacion;

  /*
  procedimiento invocado desde el proceso de fin de dia operativo
  que pasa a vencido las solicituds en estado ING, RCH o PVE
  */
  procedure pr_ven_solicitudes is

    v_can_dias number := fug_obt_pardinamico('CAN_DIA_VEN_DAT_SENSIBLES');
    v_fec_actual date := pag_Cal.FU_OBT_FEC_ACTUAL(1);
    v_cod_circuito wf_circuitos.cod_circuito%type;
    v_msg          varchar2(200) :='Pase a vencido por proceso automático';
    cursor sol is
      select cod_persona, nro_solicitud, fec_solicitud, estado
       from ge_sol_act_datos a
      where estado in ('PVE','ING','RCH') -- estados no finalizados
       and trunc(a.fec_solicitud) < (v_fec_actual - v_can_dias);

    begin
       for x in sol loop
         -- solo si tiene modificaciones en algunas de las tablas
         if pag_sad.fu_tie_modificaciones(x.nro_solicitud) <> 'N' then
           if x.estado <> 'PVE' then
             pag_sad.pr_act_est_solicitud(x.nro_solicitud,'VEN',v_msg);
           else
             pag_sad.pr_act_est_solicitud(x.nro_solicitud,'VEN',v_msg);
             -- cancelamos el workflow
             begin
                 select cod_circuito into v_cod_circuito
                   from wf_circuitos c
                 where c.cod_tip_circuito = g_cod_tip_circuito
                   and c.cod_persona = x.cod_persona
                   and c.referencia = x.nro_solicitud
                   and c.estado ='E';

                 -- cancela la tarea
                 update wf_cir_tareas wt
                    set estado = 'C'
                  where wt.cod_circuito = v_cod_circuito
                    and wt.estado ='P';
                 -- cancela el workflow
                  update wf_circuitos wc
                     set wc.fec_fin = v_fec_actual,
                         estado = 'C'
                   where cod_circuito = v_cod_circuito
                     and wc.cod_persona = x.cod_persona
                     and wc.referencia = x.nro_solicitud
                     and wc.estado='E';
              exception
                when others then
                    null;
              end;
           end if;
           if v_msg is not null then
             v_msg := 'Venc. Solicitud: '||x.nro_solicitud||'-'||v_msg;
              insert into ge_procesos_log(fecha,cod_proceso,nro_orden,hor_inicio,hor_error,error,cod_usuario)
                  values (v_fec_actual, 77,1, NULL, NULL, v_msg, user);
           end if;
         else -- si no tiene modificaciones se elimina la solicitud
           pag_sad.pr_eli_solicitud(x.nro_solicitud);
         end if;

      end loop;
    exception
       when others then
            v_msg := 'Vencimiento Solicides '||sqlerrm;
              insert into ge_procesos_log(fecha,cod_proceso,nro_orden,hor_inicio,hor_error,error,cod_usuario)
                  values (v_fec_actual, 666,10, NULL, NULL, v_msg, user);

    end pr_ven_solicitudes;
   
 --Obtiene el código de error del registro del paquete.
  FUNCTION fu_obt_cod_error return number
  IS
  BEGIN
     return pag_sad.g_cod_error;
  END fu_obt_cod_error;
  
  -- Obtiene el mensaje de error contenido en el registro del paquete.
  FUNCTION fu_obt_msj_error return varchar2
  IS
  BEGIN
     return pag_sad.g_msg_error;
  END fu_obt_msj_error;
    
  -- inicializamos las variables globales, utilizado en el WF   
  PROCEDURE pr_ini_var_globales
    IS
  begin  
      g_cod_error := 0;
      g_msg_error := null;
      g_cod_tip_circuito := to_number(fug_obt_pardinamico('COD_TIP_CIR_DAT_SENSIBLES'));
  end;    
END pag_sad;
/

