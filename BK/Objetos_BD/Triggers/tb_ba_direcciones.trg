CREATE OR REPLACE TRIGGER IT.tb_ba_direcciones
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."BA_DIRECCIONES"
 FOR EACH ROW
DECLARE
   v_cantidad       NUMBER(05);
   v_nro_cuenta     ge_dir_envios.nro_cuenta%TYPE;
   v_existe         VARCHAR2(1);
   v_localidad      ba_ciudades.descripcion%TYPE;
   v_can_tar_debito NUMBER(5);
   v_ver_programa   VARCHAR2(1);
   v_bd_user        VARCHAR2(50);
   
   v_calle          VARCHAR2(80);
   v_numero         VARCHAR2(8);
   v_piso           VARCHAR2(8);
   v_departamento   VARCHAR2(35);
   v_cod_postal     VARCHAR2(10);
   v_barrio         VARCHAR2(40);
   
BEGIN
   BEGIN
     SELECT user
     INTO v_bd_user
     from dual;     
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
         v_bd_user := '';
    END;


   BEGIN
     SELECT 'S'
     INTO v_ver_programa
     from ba_cod_referencias
     where val_minimo = nvl(pae_cnf.G_PROGRAMA,'X')
     and dominio = 'VAL_DIR_PROGRAMAS';
     EXCEPTION
       WHEN NO_dATA_FOUND THEN
         V_VER_PROGRAMA := 'N';
     END;
--if user <>   'IT' then  -- solo para que permita traspasos del APPX al oracle
-- si la insercion/ actualizacion viene de la funcionalidad de Actualizacion de Datos sensibles
-- saltamos estas validaciones por el orden en que se realizan los cambios en las tablas, las validaciones se realizan 
-- a nivel del formulario de Solicitud de actualizacion de datos. 
 if nvl(pae_cnf.G_PROGRAMA,'X') <> 'PAG_SAD' AND fue_obt_des_refcodes('USU_ALT_PERSONA', USER) <> USER then
   if(UPPER(v_bd_user) <> 'HBANK') then
    if inserting /*or updating */then
       if :new.principal = 'S' and fue_tie_dir_principal(:new.cod_persona) = 'S' then
          raise_application_error(-20000,'Cliente '||:new.cod_persona||' ya posee Direccion Principal. Verifique.');
       end if;
     end if;

    if (updating  and (nvl(:new.principal, 'X') <> nvl(:old.principal, 'X')) and (v_ver_programa = 'N')) then
       if :new.principal = 'S' and fue_tie_dir_principal(:new.cod_persona) = 'S' then
          raise_application_error(-20000,'Cliente '||:new.cod_persona||' ya posee Direccion Principal. Verifique.');
       end if;
     end if;
    end if;
  end if;

   if inserting then
      if :new.cod_direccion is null then
         begin
           select nvl(max(cod_direccion),0) + 1
           into :new.cod_direccion
           from ba_direcciones
           where cod_persona = :new.cod_persona;
           exception
           when no_data_found then
              :new.cod_direccion :=1;
              end;

      end if;
      --- Verificar que solo exista una direccion principal
      /*if :new.principal = 'S' then
         select count(*) into v_cantidad
         from ba_direcciones
         where cod_persona = :new.cod_persona
         and principal = 'S';
         if v_cantidad > 0 then
            raise_application_error(-20000,
            'Solo puede ingresar una direccion principal');
         end if;
      end if;*/
      if :new.tipo = 'H' and pae_cnf.G_PROGRAMA in ('ERCAPERS','ERREPERS') then
         raise_application_error(-20000,'No se permite ingresar/actualizar Direccion tipo BBVAnet');
      end if;
   end if;
   if updating then
      IF fug_obt_pardinamico( 'ENV_MOD_TARJETA' ) = 'S' THEN
        --- actualiza en novedades ---
/*        begin
          select e.nro_cuenta, 'S'
            into v_nro_cuenta, v_existe
            from ge_dir_envios e
           where e.cod_persona = :new.cod_persona
             and e.referencia  = :new.cod_direccion
             and e.tip_envio   = 'D';
        exception
          when others then
            v_nro_cuenta := null;
            v_existe     := null;
        end;*/
        --- descripcion de localidad ---
        begin
          select l.descripcion
            into v_localidad
            from ba_ciudades l
           where l.cod_ciudad = :new.cod_ciudad;
        exception
          when others then
            v_localidad := null;
        end;

        if :old.direccion <> :new.direccion
         or  :old.numero    <> :new.numero
         or  :old.dir_lateral    <> :new.dir_lateral
         or  :old.edificio <> :new.edificio
         or  :old.piso <> :new.piso
         or  :old.departamento <> :new.departamento then
          DECLARE
            v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);
            CURSOR cuentas
--RI : 13/05/2010 : solo debe grabar novedad si se modifica la direccion personalizada
-- para la cuenta de tarjeta
/*                IS select c.nro_cuenta
                     from ge_cta_clientes c, ta_cta_tarjetas t
                    where c.cod_persona = :new.cod_persona
                      and c.nro_cuenta  = nvl( v_nro_cuenta, c.nro_cuenta )
                      and c.nro_cuenta  = t.nro_cuenta
                      and c.relacion    = 'P'
                      and t.estado      <> 'C';*/
            IS select t.nro_cuenta
                     from ta_cta_tarjetas t, ge_dir_envios d
                    where d.cod_persona = :new.cod_persona
                      and d.tip_envio   = 'D'
                      and d.referencia  = :new.cod_direccion
                      and t.nro_cuenta  = d.nro_cuenta
                      and t.estado      <> 'C'
                      AND fut_obt_procesadora(t.nro_cuenta) != fug_obt_pardinamico('COD_ENT_GLOBAL');
          BEGIN
            FOR d IN cuentas LOOP
              BEGIN
                update ta_cta_tarjetas_nov
                   set dir_envio = substr( :new.direccion||' '||:new.numero||' '||:new.dir_lateral, 1, 250 ),
                       localidad = v_localidad,
                       enviado   = 'N',
                       aprobado  = 'N',
                       nro_acta  = null,
                       niv_aprobacion = null
                 where nro_cuenta = d.nro_cuenta
                   and fecha = v_fec_actual;
                IF SQL%NOTFOUND THEN
                  BEGIN
                    insert into ta_cta_tarjetas_nov( nro_cuenta,
                                                     fecha,
                                                     dir_envio,
                                                     enviado,
                                                     localidad )
                                             values( d.nro_cuenta,
                                                     v_fec_actual,
                                                     substr( :new.direccion||' '||:new.numero||' '||:new.dir_lateral, 1, 250 ),
                                                     'N',
                                                     v_localidad );
                  EXCEPTION
                    when others then
                      IF sqlcode <= -20000 THEN
                        RAISE;
                      ELSE
                        RAISE_APPLICATION_ERROR( -20412, 'No se pudo insertar la novedad para la tarjeta ' || sqlerrm );
                      END IF;
                  END;
                END IF;
              EXCEPTION
                when others then
                  IF sqlcode <= -20000 THEN
                    RAISE;
                  ELSE
                    RAISE_APPLICATION_ERROR( -20413, 'No se pudo actualizar la novedad para la tarjeta ' || sqlerrm );
                  END IF;
              END; 
            END LOOP;
          END;
        end if;
     end if;--fin parametro actualizar novedad
      --- Fin actualizacion de novedades ---
      if :new.tipo = 'H' and pae_cnf.G_PROGRAMA in ('ERCAPERS','ERREPERS') then
         raise_application_error(-20000,'No se permite ingresar/actualizar Direccion tipo BBVAnet');
      end if;
      -- Novedades Global Processing --
      if fug_obt_pardinamico( 'ENV_MOD_TARJETA_GP' ) = 'S'
        and :new.principal = 'S' and :new.tipo = 'P' then--solo se tendran en cuenta los registros marcados como principal y de tipo particular.
        if (nvl(:old.direccion,'X')     <> nvl(:new.direccion,'X')
          or nvl(:old.numero,'X')       <> nvl(:new.numero,'X')
          or nvl(:old.piso,'X')         <> nvl(:new.piso,'X')
          or nvl(:old.departamento,'X') <> nvl(:new.departamento,'X')
          or nvl(:old.cod_postal,'X')   <> nvl(:new.cod_postal,'X')
          or nvl(:old.cod_barrio,0)     <> nvl(:new.cod_barrio,0))
          and nvl(:new.tipo,'X') in ('P','L')then

           v_calle      := substr(:new.direccion,1,35);
           v_numero     := :new.numero;
           v_piso       := substr(:new.piso,1,2);
           v_departamento := :new.departamento;
           v_cod_postal := substr(:new.cod_postal,1,8);
           v_barrio     := fue_obt_des_barrio(:new.cod_pais,:new.cod_ciudad,:new.cod_barrio);

           declare
               v_fec_actual date := pag_cal.fu_obt_fec_actual(3);
              cursor cuentas is
               select c.nro_cuenta, t.nro_cta_global
                 from ge_cta_clientes c, ah_tar_debitos t
                where c.cod_persona = :new.cod_persona
                  and c.nro_cuenta  = t.nro_cuenta
                  and c.relacion    = 'P'
                  and t.nro_cta_global is not NULL
                  AND t.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
                  and rownum = 1;

           begin
             for d in cuentas LOOP
              begin
               if :new.tipo = 'P' then--direccion particular
                update TA_GLP_CUENTAS_NOV
                   set enviado = 'N',
                       cal_particular = v_calle,
                       nro_particular = v_numero,
                       pis_particular = v_piso,
                       dep_particular = v_departamento,
                       cod_pos_particular = v_cod_postal,
                       bar_particular = v_barrio,
                       fec_novedad = v_fec_actual
                 where nro_cuenta = d.nro_cuenta
                   and nro_cta_global = d.nro_cta_global
                   and fec_novedad = v_fec_actual;

                   if sql%notfound then
                     begin
                       insert into TA_GLP_CUENTAS_NOV(nro_cuenta,
                                                        nro_cta_global,
                                                        cal_particular,
                                                        nro_particular,
                                                        pis_particular,
                                                        dep_particular,
                                                        cod_pos_particular,
                                                        bar_particular,
                                                        fec_novedad)
                                                 values(d.nro_cuenta,
                                                        d.nro_cta_global,
                                                        v_calle,
                                                        v_numero,
                                                        v_piso,
                                                        v_departamento,
                                                        v_cod_postal,
                                                        v_barrio,
                                                        v_fec_actual );
                     exception
                       when others then
                         if sqlcode <= -20000 then
                          raise;
                         else
                          raise_application_error( -20414, 'No se pudo insertar la novedad para la tarjeta ' || sqlerrm );
                         end if;
                     end;
                   end if;
               elsif :new.tipo = 'L' then--direccion laboral(esta parte queda por si se habilita la actualizacion laboral,aactualmente solo se dejaran actualizar las direcciones con tipo particular)
                update TA_GLP_CUENTAS_NOV
                   set enviado = 'N',
                       cal_laboral = v_calle,
                       nro_laboral = v_numero,
                       pis_laboral = v_piso,
                       dep_laboral = v_departamento,
                       cod_pos_laboral = v_cod_postal,
                       bar_laboral = v_barrio,
                       fec_novedad = v_fec_actual
                 where nro_cuenta = d.nro_cuenta
                   and nro_cta_global = d.nro_cta_global
                   and fec_novedad = v_fec_actual;

                   if sql%notfound then
                     begin
                       insert into TA_GLP_CUENTAS_NOV(nro_cuenta,
                                                       nro_cta_global,
                                                       cal_laboral,
                                                       nro_laboral,
                                                       pis_laboral,
                                                       dep_laboral,
                                                       cod_pos_laboral,
                                                       bar_laboral,
                                                       fec_novedad)
                                                values(d.nro_cuenta,
                                                       d.nro_cta_global,
                                                       v_calle,
                                                       v_numero,
                                                       v_piso,
                                                       v_departamento,
                                                       v_cod_postal,
                                                       v_barrio,
                                                       v_fec_actual );
                     exception
                       when others then
                         if sqlcode <= -20000 then
                           raise;
                         else
                           raise_application_error( -20414, 'No se pudo insertar la novedad para la tarjeta ' || sqlerrm );
                         end if;
                     end;
                   end if;
               end if;
              end;
             end loop;
           end;
        end if;
      end if;
   end if;
   if deleting and  pae_cnf.G_PROGRAMA <> 'PAG_SAD' then
      --- Verificar que no existan direcciones de envio relacionadas
     select nvl(count(*),0)
      into v_cantidad
         from ge_dir_envios
     where cod_persona = :old.cod_persona
       and tip_envio = 'D'
       and referencia = :old.cod_direccion;
    if v_cantidad > 0 then
      raise_application_error(-20000,
      'Existen direcciones de envio relacionadas');
    end if;

    /*07/01/2014 PN DI: Verifica que no se borren direcciones que se encuentran en la tabla
                        ah_tar_debitos */
     select nvl(count(*),0)
      into v_can_tar_debito
       from ah_tar_debitos
     where cod_persona = :old.cod_persona
       and tip_envio = 'D'
       and referencia = :old.cod_direccion;

    if nvl(v_can_tar_debito,0) > 0 then
        raise_application_error(-20000,'Esta direccion esta vinculada con Tarjetas Debitos. Verifique.');
    end if;

   end if;
--end if;
END;
/

