CREATE OR REPLACE TRIGGER IT.TA_AH_TAR_DEBITOS
 AFTER DELETE OR INSERT OR UPDATE
 ON AH_TAR_DEBITOS
 FOR EACH ROW

DECLARE
 v_new_cta_alias ah_cta_ficticias.nro_cuenta%type;
 v_exi_cta char(1) :='N';
 v_lugar   varchar2(100);
 v_cod_procesadora ah_tar_debitos.cod_ent_procesadora%type := fug_obt_pardinamico('COD_PRO_BANCARD');
 v_nro_bin_mc  ah_tar_debitos.nro_bin%type := fug_obt_parentes(v_cod_procesadora,'NRO_BIN_TDD_MASTERCARD');
 v_nro_bin_mcb ah_tar_debitos.nro_bin%type := fug_obt_parentes(v_cod_procesadora,'NRO_BIN_TDD_MASTERCARD_BLACK');
 v_nro_bin_infonet ah_tar_debitos.nro_bin%type := fug_obt_parentes(v_cod_procesadora,'NRO_BIN_TDD_INFONET');
 v_random_existente ah_cta_ficticias.nro_cuenta%type;

 -- funcion que genera en forma random un numero que sera la cuenta alias de la TDD -SDBIN8TDD-1
   FUNCTION lf_obt_cta_alias
   RETURN NUMBER IS
      v_nro_random number(10):=0;
      v_nro_cta_alias ah_tar_cta_ficticias.nro_cuenta%type;
      v_existe char(1) :='N';
       -- obtenemos el rango definido segun el tipo de tarjeta
      v_rng_producto number := fue_obt_des_refcodes('COD_PRO_TAR_DEBITO', :new.tip_tar_debito);
      -- prefijo definido para Mastercard
      v_prefijo_mc varchar2(2) := fug_obt_parentes(v_cod_procesadora,'NRO_BIN_PREFIJO_MC');

   BEGIN
      v_lugar:= 'En lf_obt_cta_alias';
      ---
      LOOP
       BEGIN
       v_lugar := 'Obt Nro Random '||v_nro_random;
        --obtenemos un numero random de 6 digitos que corresponde a la cuenta alias
        v_nro_random := dbms_random.value(0,999999); -- 6 posiciones
        --
        v_lugar := 'Random despues '||v_nro_random;

        -- concateno cuenta alias
       -- si es un bin de mastercard, se concatena con el prefijo para Mastercard
       if :new.nro_bin in (v_nro_bin_mc,v_nro_bin_mcb) and v_random_existente is null then
          v_nro_cta_alias := v_prefijo_mc||v_rng_producto||lpad(v_nro_random,6,'0');
          v_lugar := 'Cta Alias MC '||v_nro_cta_alias;
       elsif :new.nro_bin = v_nro_bin_mcb and v_random_existente is not null then--BSEVOCORE-1029- Si ya tiene mastercard,
          v_nro_cta_alias := v_prefijo_mc||v_rng_producto||v_random_existente;   --se cambio solo el rango de 0 a 1 para la black
          v_lugar := 'Cta Alias MC BLACK'||v_nro_cta_alias;
       end if;

       -- verificamos si el random generado ya existe o no en la tabla.
       -- En caso que no exista el numero generado, retorna dicho numero
       -- En caso que ya exista entonces sigue dentro del loop hasta que se genere un numero que no exista.

       SELECT 'S'
           INTO v_existe
           FROM ah_tar_cta_ficticias
          WHERE nro_cuenta = v_nro_cta_alias
           and nro_bin = :new.nro_bin;
       EXCEPTION
         WHEN no_data_found THEN
           v_existe := 'N';
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al obt. Cta. alias ' ||v_lugar||'-'||SQLERRM);
       END;
        exit when v_existe = 'N';

      end loop;

      RETURN v_nro_cta_alias;
   END;

/******** Inicio *******/
BEGIN
  -- cuando la solicitud de TDD cambia al estado Pend. de Envio a Infonet se genera la cuenta alias.
   if updating
      and :old.cod_est_solicitud <> :new.cod_est_solicitud
      and :new.cod_est_solicitud= 5 /*Pend.Envio*/
      and :new.nro_bin in (v_nro_bin_mc,v_nro_bin_mcb) /* Solo mastercard generamos con cuenta alias */
   then
     -- el campo no es obligatorio, pero hacemos la validacion
     if :new.tip_tar_debito is null then
         raise_application_error(-20003, 'Favor ingresar Tipo de TDD');
     end if;

     --
     v_lugar :='Validacion del BIN:';
     if fug_obt_pardinamico('VAL_BIN_SOL_TDD')='S' then
       if :new.nro_bin <> v_nro_bin_mc and
          :new.nro_bin <> v_nro_bin_mcb and
          :new.nro_bin <> v_nro_bin_infonet then
          raise_application_error(-20010,v_lugar||:new.nro_bin||' no se encuentra vigente.');
       end if;
     end if;

      ---
      v_lugar := 'Obtiene random de cta alias ya existente';-----BSEVOCORE-1029--Se agrega para obtener random ya existente
      begin                                                                    --si se pasa de mastercard normal a black
         select substr (f.nro_cuenta,4,10)
           into v_random_existente
           from ah_tar_cta_ficticias f
          where f.nro_cta_cliente = :new.nro_cuenta
            and f.nro_bin = v_nro_bin_mc;
      exception
         when no_data_found then
            v_lugar := 'obtiene random ya existente';
            v_random_existente := null;
            ---
         when others then
           raise_application_error(-20001,v_lugar||'-Error obt. Random Existente '||sqlerrm);

      end;
      ---
      v_lugar := 'Verifica si existe cta alias';
      begin
         select 'S' into v_exi_cta
           from ah_tar_cta_ficticias f
          where f.nro_cta_cliente = :new.nro_cuenta
            and f.nro_bin = :new.nro_bin;
      exception
         when no_data_found then
            v_lugar := 'ANTES de lf_obt_cta_alias';
            -- si no existe aun la cuenta, generamos la cuenta alias
            v_exi_cta :='N';
            v_new_cta_alias := lf_obt_cta_alias;
            ---
         when others then
           raise_application_error(-20001,v_lugar||'-Error obt. Cuenta Alias '||sqlerrm);

      end;
      -- si aun no tiene cuenta alias, insertamos en la tabla relacion
      if v_exi_cta ='N' and v_new_cta_alias is not null then
        begin
           v_lugar := 'Insert ah_tar_cta_ficticias';
          insert into ah_tar_cta_ficticias(nro_cuenta,nro_cta_cliente, nro_bin)
            values(v_new_cta_alias, :new.nro_cuenta, :new.nro_bin);
        exception
          when others then
           raise_application_error(-20002,v_lugar||'-Error ins.Ah_tar_cta_ficticias '||sqlerrm);
        end;   
      end if;
   end if;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20004,v_lugar||sqlerrm);
END;
/

