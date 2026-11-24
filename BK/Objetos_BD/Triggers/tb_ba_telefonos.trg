CREATE OR REPLACE TRIGGER IT.TB_BA_TELEFONOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."BA_TELEFONOS"
 FOR EACH ROW
DECLARE
   v_cantidad number(05);
   v_existe varchar2(1) default 'N';--DYDMR-6133 - 15/02/2017
   v_celular ba_telefonos.telefono%TYPE;
BEGIN
   if inserting then
      --- Generar codigo de telefono
      --en la migracion el sqlloader da mutating si se vuelve a consultar la tabla
      if nvl(PAE_CNF.G_PROGRAMA,'x') IN ('ERREPERS','ERCAPERS','ERAGENDA','ERAGEPER','GMPROARC') then
        if :new.cod_telefono is null then
          begin
           select nvl(max(cod_telefono),0) + 1
           into :new.cod_telefono
           from ba_telefonos
           where cod_persona = :new.cod_persona;
           exception
           when no_data_found then
           :new.cod_telefono :=1;
           end;
        end if;
       else
         --para la migracion
         if :new.cod_telefono is null then
             if :new.tipo = 'P' then
                :new.cod_telefono := 1;
             elsif :new.tipo = 'L' then
                :new.cod_telefono := 2;
             else
                :new.cod_telefono := 3;
             end if;
          end if;
      end if;
      --- Verificar que solo exista un telefono principal
      if nvl(PAE_CNF.G_PROGRAMA,'x') IN ('ERREPERS','ERCAPERS','ERAGENDA','ERAGEPER','GMPROARC') then
        if :new.principal = 'S' then
          if nvl(pae_cnf.G_PROGRAMA,'X') <> 'PAG_SAD' then
             select count(*) into v_cantidad
             from ba_telefonos
             where cod_persona = :new.cod_persona
             and principal = 'S';
             if v_cantidad > 0 then
                raise_application_error(-20000,
                'Solo puede ingresar un telefono principal');
             end if;
          end if; 
        end if;
        --- Validar formato del telefono
        pre_ver_fmt_telefono(:new.telefono);
      end if;
   end if;
   if updating then
      if :new.telefono <> :old.telefono then
        --- Validar formato del telefono
        pre_ver_fmt_telefono(:new.telefono);
      end if;
   end if;

   ---Control para evitar que se ingrese comentarios o nombres de ciudades como codigo de area
   if inserting or updating then
     if substr(:new.telefono, 1, 4) = '+595' then
      :new.telefono := '0' || substr(:new.telefono, 5);
     end if;    
     if fue_val_es_numerico(:new.area) = 'N' then
          raise_application_error(-20000,
          'Codigo de area Invalido...Solo puede ingresar numeros como codigo de area');
     end if;
      IF fug_obt_pardinamico( 'ENV_MOD_TARJETA' ) = 'S' THEN
        IF nvl(pae_cnf.G_PROGRAMA,'X') NOT IN( 'GPPROFIN', 'GPPROIND' ) THEN
          IF nvl( :old.telefono, ' ' ) <> nvl( :new.telefono, ' ' ) OR
             nvl( :old.area, ' ' ) <> nvl( :new.area, ' ' ) THEN
            IF nvl( :new.principal, 'N' ) = 'S' THEN
              DECLARE
                v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);
                v_telefono   VARCHAR2(20);
                CURSOR cuentas
                    IS select c.nro_cuenta
                         from ge_cta_clientes c, ta_cta_tarjetas t
                        where c.cod_persona = :new.cod_persona
                          and c.nro_cuenta = t.nro_cuenta
                          and c.relacion = 'P'
                          and t.estado <> 'C'
                          AND fut_obt_procesadora(c.nro_cuenta) != fug_obt_pardinamico('COD_ENT_GLOBAL');
              BEGIN
                FOR d IN cuentas LOOP
                  v_telefono := NULL;
                  IF :new.area IS NOT NULL THEN
                    v_telefono := '(' || :new.area || ') ';
                  END IF;
                  v_telefono := v_telefono || :new.telefono;
                  BEGIN
                    update ta_cta_tarjetas_nov
                       set tel_principal = v_telefono,
                           enviado       = 'N',
                           aprobado  = 'N',
                           nro_acta  = null,
                           niv_aprobacion = null
                     where nro_cuenta = d.nro_cuenta
                       and fecha = v_fec_actual;
                    IF SQL%NOTFOUND THEN
                      BEGIN
                        insert into ta_cta_tarjetas_nov( nro_cuenta,
                                                         fecha,
                                                         tel_principal,
                                                         enviado )
                                                 values( d.nro_cuenta,
                                                         v_fec_actual,
                                                         v_telefono,
                                                         'N' );
                      EXCEPTION
                        when others then
                          IF sqlcode <= -20000 THEN
                            RAISE;
                          ELSE
                            RAISE_APPLICATION_ERROR( -20312, 'No se pudo insertar la novedad para la tarjeta ' || sqlerrm );
                          END IF;
                      END;
                    END IF;
                  EXCEPTION
                    when others then
                      IF sqlcode <= -20000 THEN
                        RAISE;
                      ELSE
                        RAISE_APPLICATION_ERROR( -20313, 'No se pudo actualizar la novedad para la tarjeta ' || sqlerrm );
                      END IF;
                  END;
                END LOOP;
              END;
            END IF;
          END IF;
        END IF;
      END IF;
      if :new.tipo = 'H' and pae_cnf.G_PROGRAMA in ('ERCAPERS','ERREPERS') then
         raise_application_error(-20000,'No se permite ingresar/actualizar Telefono tipo BBVAnet');
      end if;
       -- Novedades Global Processing --
      if fug_obt_pardinamico( 'ENV_MOD_TARJETA_GP' ) = 'S'
        and :new.principal = 'S' and :new.tipo = 'P' then--solo se tendran en cuenta los registros marcados como principal y de tipo particular.
       if (nvl( :old.telefono, ' ' ) <> nvl( :new.telefono, ' ' )
         or nvl( :old.area, ' ' ) <> nvl( :new.area, ' ' ))
        and nvl(:new.tip_linea, 'B') = 'C' then
        declare
         v_fec_actual date := pag_cal.fu_obt_fec_actual(3);
         cursor cuentas is
          select c.nro_cuenta, t.nro_cta_global
            from ge_cta_clientes c, ah_tar_debitos t
           where c.cod_persona = :new.cod_persona
             and c.nro_cuenta  = t.nro_cuenta
             and c.relacion    = 'P'
             AND t.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
             and t.nro_cta_global is not null
             and rownum = 1;
        begin
         for d in cuentas LOOP
           v_celular := substr(nvl(:new.area,''),1,4) || substr(:new.telefono,1,14);
          begin
           update TA_GLP_CUENTAS_NOV
              set enviado = 'N',
                  tel_celular = v_celular,
                  fec_novedad = v_fec_actual
            where nro_cuenta = d.nro_cuenta
              and nro_cta_global = d.nro_cta_global
              and fec_novedad = v_fec_actual;
           if sql%notfound then
            begin
             insert into TA_GLP_CUENTAS_NOV(nro_cuenta,
                                             nro_cta_global,
                                             tel_celular,
                                             fec_novedad)
                                      values(d.nro_cuenta,
                                             d.nro_cta_global,
                                             v_celular,
                                             v_fec_actual);
            exception
             when others then
              if sqlcode <= -20000 then
               raise;
              else
               raise_application_error( -20314, 'No se pudo insertar la novedad para la tarjeta ' || sqlerrm );
              end if;
            end;
           end if;
          end;
         end loop;
        end;
       end if;
      end if;
   end if;
   --DYDMR-6133 - 15/02/2017 ------------------------------------
   IF DELETING or UPDATING THEN
    IF TRIM(UPPER(:OLD.TIP_LINEA)) = 'C' THEN
     BEGIN
      SELECT 'S'
        INTO V_EXISTE
        FROM BW_OTP_REF_MEDIOS M
        WHERE UPPER(M.TIPO) = 'C'
          AND M.REF_MEDIO = TRIM(:OLD.AREA)||TRIM(:OLD.TELEFONO);
     EXCEPTION
       WHEN OTHERS THEN
         V_EXISTE := 'N';
     END;
     IF V_EXISTE = 'S' THEN
       DELETE BW_OTP_REF_MEDIOS M
       WHERE M.COD_PERSONA = :OLD.COD_PERSONA
         AND M.REF_MEDIO = TRIM(:OLD.AREA)||TRIM(:OLD.TELEFONO)
         AND UPPER(M.TIPO) = 'C';
     END IF;
    END IF;
   END IF;
   --------------------------------------------------------------
END;
/

