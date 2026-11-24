create or replace procedure it.prm_tra_oficiales is
   --- Proceso automático que transfiere oficiales en forma masiva
   v_cod_seg_cliente  ge_clientes.cod_seg_cliente%type;
   v_cod_usu_oficial  ge_clientes.cod_usu_oficial%type;
   v_cantidad number(3);
   -- Requerimiento: CNFDEEVO-30(Mejoras).
   -- Fecha: 15/03/2016.
   v_destinatario     tm_mails.env_para%type;
   v_nro_traspaso    ge_tra_cli_oficial.nro_traspaso%type;
   v_nro_orden    ge_tra_cli_oficial.nro_orden%type;
   v_fecha  date := pag_cal.fu_obt_fec_actual(1);
   v_cod_programa  ge_tra_cli_oficial.cod_programa%type := pae_cnf.fu_obt_cod_programa;
   -- Cursor principal.
   cursor c_cambios is
   select * from tm_ge_clientes;
begin   
   --- Valida oficiales
   -- Requerimiento: CNFDEEVO-30(Mejoras).
   -- Fecha: 15/03/2016.
   -- Se agrega la validación en el cursor.
   /*select count(*) into v_cantidad
     from tm_ge_clientes e
    where not exists(select 1 from ba_usuarios u
                      where u.cod_usuario = e.cod_usu_oficial
                        and u.oficial = 'S');
   if v_cantidad > 0 then
      raise_application_error(-20000,'Oficiales no corresponden verifique planilla');
   end if;*/
   --- Proceso principal
   begin
     select S_NRO_TRASPASO.nextval
       into v_nro_traspaso
       from dual;
   exception
     when others then
       raise_application_error(-20000, 'No se puede obtener el número de secuencia. '||sqlerrm);
   end;
    
   for reg in c_cambios loop
      -- Requerimiento: CNFDEEVO-30(Mejoras).
      -- Fecha: 15/03/2016.
      -- Validación del gestor.
      BEGIN
         SELECT 1 
           INTO v_cantidad
           FROM ba_usuarios u
          WHERE u.cod_usuario = reg.cod_usu_oficial
            AND u.oficial = 'S';
      EXCEPTION
         WHEN OTHERS THEN
            -- Mail que no se realizo el cambio de gestor.
            BEGIN
               v_destinatario := fug_obt_pardinamico('GEN_ENV_CAM_GESTOR');
               it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), 
                             v_destinatario, 
                             'Proceso de Cambio de Gestor - Fecha de Modificación: '||to_char(sysdate, 'dd/mm/yyyy'),
                             'Oficial no registrado: '||reg.cod_usu_oficial||', no fue procesado el cambio de gestor del Cliente: '||reg.cod_persona);
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
            --
            v_cantidad := 0;
      END;
      -- 
      IF v_cantidad > 0 THEN
         -- Verifico si existe el Cliente.
         BEGIN
            SELECT 1 
              INTO v_cantidad
              FROM ge_clientes
             WHERE cod_persona = reg.cod_persona;
         EXCEPTION
            WHEN OTHERS THEN
               -- Mail que no se realizo el cambio de gestor.
               BEGIN
                  v_destinatario := fug_obt_pardinamico('GEN_ENV_CAM_GESTOR');
                  it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), 
                                v_destinatario, 
                                'Proceso de Cambio de Gestor - Fecha de Modificación: '||to_char(sysdate, 'dd/mm/yyyy'),
                                'Cliente no registrado: '||reg.cod_persona||', no fue procesado el cambio de gestor.');
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
               --
               v_cantidad := 0;
         END;
         -- Si existe el cliente actualizo los datos en la tabla.
         IF v_cantidad > 0 THEN
            begin
               select cod_seg_cliente, cod_usu_oficial
                 into v_cod_seg_cliente, v_cod_usu_oficial
                 from ge_clientes
                where cod_persona = reg.cod_persona;
               if v_cod_seg_cliente is null then 
                  v_cod_seg_cliente := 28; -- Empresas según definición de Natalia Miers en mail del 31/08/09
               end if;
               
               begin
                 v_nro_orden := nvl(v_nro_orden, 0) + 1;
                 
                 insert into ge_tra_cli_oficial ( nro_traspaso,
                                                  nro_orden,
                                                  fecha,
                                                  cod_persona,
                                                  cod_usu_ofi_des,
                                                  cod_usu_ofi_ori,
                                                  cod_programa )
                                         values ( v_nro_traspaso,
                                                  v_nro_orden,
                                                  v_fecha,
                                                  reg.cod_persona,
                                                  reg.cod_usu_oficial,
                                                  v_cod_usu_oficial,
                                                  v_cod_programa );
              exception
                when others then
                  BEGIN
                    v_destinatario := fug_obt_pardinamico('GEN_ENV_CAM_GESTOR');
                    it_mail.mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), 
                                  v_destinatario, 
                                  'Proceso de Cambio de Gestor - Fecha de Modificación: '||to_char(sysdate, 'dd/mm/yyyy'),
                                  'No se pudo insertar el Historial del Cambio de Gestor de la persona: '||reg.cod_persona||'.');
                 EXCEPTION
                    WHEN OTHERS THEN
                       NULL;
                 END;
               END;
                                                  
               update ge_clientes
                  set cod_usu_oficial = reg.cod_usu_oficial,
                      cod_seg_cliente = nvl(cod_seg_cliente, v_cod_seg_cliente)
                where cod_persona = reg.cod_persona;
            exception
               when others then
                 null;
            end;
         END IF;
      END IF;
   end loop;
   -- Requerimiento: CNFDEEVO-30.
   -- Fecha: 04/03/2016.
   delete tm_ge_clientes;
EXCEPTION
  WHEN OTHERS THEN
     delete tm_ge_clientes;
     -- Requerimiento: CNFDEEVO-30(Mejoras).
     -- Fecha: 15/03/2016.     
     --raise_application_error(-20001, ' Error.'|| ' - ' || SQLERRM);   
end prm_tra_oficiales;
/

