CREATE OR REPLACE TRIGGER IT.TB_GE_DIR_ENVIOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT"."GE_DIR_ENVIOS"
 FOR EACH ROW
DECLARE
  v_dir VARCHAR2(500);
  v_localidad ba_ciudades.descripcion%type;
BEGIN
  IF updating OR inserting THEN
    IF fug_obt_pardinamico( 'ENV_MOD_TARJETA' ) = 'S' THEN
      IF nvl(pae_cnf.G_PROGRAMA,'X') NOT IN( 'GPPROFIN', 'GPPROIND' ) then
        IF nvl( :old.tip_envio, ' ' ) <> nvl( :new.tip_envio, ' ' ) OR
           nvl( :old.referencia, ' ' ) <> nvl( :new.referencia, ' ' ) OR
           nvl( :old.observacion, ' ' ) <> nvl( :new.observacion, ' ' ) OR
           nvl( :old.nro_cuenta, ' ') <> nvl(:new.nro_cuenta,' ') THEN
          IF nvl( :new.tip_envio, ' ' ) = 'D' THEN -- Direccion
            BEGIN
              select d.direccion||decode(numero,null,'',' '||numero)||' '||d.dir_lateral, c.descripcion
                into v_dir, v_localidad
                from ba_direcciones d,
                     ba_ciudades c
               where cod_persona = :new.cod_persona
                 and cod_direccion = :new.referencia
                 and d.cod_ciudad  = c.cod_ciudad (+)
                 and rownum = 1;
            EXCEPTION
              when others then
                v_dir := NULL;
            END;
          ELSIF nvl( :new.tip_envio, ' ' ) = 'C' THEN -- Casillero
            v_dir := 'CASILLERO: ' || :new.referencia;
          ELSIF nvl( :new.tip_envio, ' ' ) = 'A' THEN -- Casilla de correo
            v_dir := 'CASILLA DE CORREO: ' || :new.referencia;
          ELSIF nvl( :new.tip_envio, ' ' ) = 'N' THEN -- No imprimir
            v_dir := 'NO IMPRIMIR';
          ELSIF nvl( :new.tip_envio, ' ' ) = 'R' THEN -- Retener
            BEGIN
              select 'RETENER EN ' || descripcion
                into v_dir
                from ge_dir_retenciones
               where cod_dir_retencion = :new.referencia;
            EXCEPTION
              when others then
                v_dir := NULL;
            END;
          END IF;

          DECLARE
            v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);            
            CURSOR cuentas
--RI : 13/05/2010 : solo debe grabar novedad si se modifica la direccion personalizada
-- para la cuenta de tarjeta            
 /*               IS select c.nro_cuenta
                     from ge_cta_clientes c, ta_cta_tarjetas t
                    where c.cod_persona = :new.cod_persona
                      and c.nro_cuenta = nvl( :new.nro_cuenta, c.nro_cuenta )
                      and c.nro_cuenta = t.nro_cuenta
                      and c.relacion = 'P'
                      and t.estado <> 'C';*/
            IS select t.nro_cuenta
                     from ta_cta_tarjetas t
                    where t.nro_cuenta = :new.nro_cuenta
                      and t.estado      <> 'C'
                      AND fut_obt_procesadora(t.nro_cuenta) != fug_obt_pardinamico('COD_ENT_GLOBAL');                                            
          BEGIN
            FOR d IN cuentas LOOP
              begin
                if fug_obt_cli_principal(:new.nro_cuenta)<> :new.cod_persona then
                   RAISE_APPLICATION_ERROR( -20413, 'La Persona '||:new.cod_persona||' no es Principal de la Cuenta ' || :new.nro_cuenta||', favor verifique.' );                end if;
                update ta_cta_tarjetas_nov
                   set dir_envio = substr( v_dir, 1, 250 ),
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
                                                     substr( v_dir, 1, 250 ),
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
        END IF;
      END IF;
      --- RI:16/07/2010: Si se modifica la cuenta, eliminar registro de la cuenta anterior 
      --- si la misma no fue aprobada ni enviada
  /*dydmr-463 fmolinas  se agrega la condición */
    if nvl( :old.nro_cuenta, ' ') <> nvl(:new.nro_cuenta,' ') THEN    
      Declare
       CURSOR cuentas IS
       select t.nro_cuenta from ta_cta_tarjetas t
        where t.nro_cuenta = :old.nro_cuenta
          and t.estado      <> 'C'
          AND fut_obt_procesadora(t.nro_cuenta) != fug_obt_pardinamico('COD_ENT_GLOBAL');
      BEGIN
        FOR d IN cuentas LOOP
          Delete ta_cta_tarjetas_nov
           where nro_cuenta = d.nro_cuenta
             and nvl(aprobado,'N') = 'N'
             and nvl(enviado,'N') = 'N'
             and dir_envio is not null;
        END LOOP;
      END;
      ---
    end if;       
    END IF;
  END IF;
--RI : 09/07/2010 : Eliminar la novedad si se elimina el registro de direccion 
--personalizada para la cuenta de tarjeta            
  IF DELETING THEN
    IF fug_obt_pardinamico( 'ENV_MOD_TARJETA' ) = 'S' THEN       
       Declare
       CURSOR cuentas IS
       select t.nro_cuenta from ta_cta_tarjetas t
        where t.nro_cuenta = :old.nro_cuenta
          and t.estado      <> 'C'
          AND fut_obt_procesadora(t.nro_cuenta) != fug_obt_pardinamico('COD_ENT_GLOBAL');
       BEGIN
        FOR d IN cuentas LOOP
          Delete ta_cta_tarjetas_nov
           where nro_cuenta = d.nro_cuenta
             and nvl(aprobado,'N') = 'N'
             and nvl(enviado,'N') = 'N'
             and dir_envio is not null;
        END LOOP;
       END;
    END IF;
  END IF;  
END;
/

