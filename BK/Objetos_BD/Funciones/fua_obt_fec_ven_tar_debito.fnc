create or replace function it.fua_obt_fec_ven_tar_debito(p_nro_cuenta in varchar2,
                                                      p_cod_persona in varchar2,
                                                      p_adherente in varchar2,
                                                      p_nro_bin in varchar2) return date is
  --Proyecto SDFNVTDD-1 Vto Aleatorio de Tarjeta Debito por Fraude--
  -- Parametro p_nro_bin agregado para obtener correctamente la TDD-SDBIN8TDD-1
  type vector is table of date index by binary_integer;
  vec_fec_cal vector;
  vec_fec_ant vector;

  --Variables--
  v_tie_tar_anu_fraude varchar2(1);
  v_fec_ven_tar_debito date;
  v_fecha date;
  v_fec_inicial date;
  v_can_ven_tar_debito number(10);
  v_ind_fec_valida varchar2(1);
  v_ind_exi_fecha varchar2(1);
  v_indice number(6);
  v_fec_calculada date;
  v_fec_aleatoria date;
  v_nro_aleatoria number(6);
  v_max_nro_emision ah_tar_debitos.nro_emision%type;
  v_nro_bin ge_par_entes.val_parametro%type;
  v_fec_ven_anterior date;
begin
  v_fecha := pag_cal.fu_obt_fec_actual(3);
  v_nro_bin := fug_obt_parentes(fug_obt_pardinamico('COD_PRO_BANCARD'),'NRO_BIN_TDD_MASTERCARD');  -- Se modifica parametro d Visa por Mastercard
  v_tie_tar_anu_fraude := 'N';
  v_tie_tar_anu_fraude := fua_ver_tar_anu_fraude(p_nro_cuenta, p_cod_persona, p_adherente, p_nro_bin);
  if nvl(v_tie_tar_anu_fraude,'N') = 'N' then
     raise_application_error(-20002, 'Error. Ultima Emision de Tarjeta de Debito no tiene anulacion por Fraude '||sqlerrm);
  elsif nvl(v_tie_tar_anu_fraude,'N') <> 'S' then
     raise_application_error(-20002, 'Error en fua_obt_fec_ven_tar_debito: '||sqlerrm);
  else
    --Sigue calculando si v_tie_tar_anu_fraude = S y devuelve v_fec_ven_tar_debito valido--
    --Calcula y guarda fechas no validas relacionadas al vencimiento anterior--
    v_max_nro_emision := fua_obt_max_nro_emision(p_nro_cuenta, p_cod_persona, p_adherente);
    select b.fec_vencimiento
      into v_fec_ven_anterior
      from ah_tar_debitos b
     where b.nro_cuenta  = p_nro_cuenta
       and b.cod_persona = p_cod_persona
       and lpad(to_char(to_number(b.adherente)),2,'0') = p_adherente
       and b.nro_emision = v_max_nro_emision
       and b.nro_bin     = nvl(p_nro_bin, v_nro_bin);
     vec_fec_ant(1):= v_fec_ven_anterior;
     vec_fec_ant(2):= add_months(v_fec_ven_anterior,1);
     vec_fec_ant(3):= add_months(v_fec_ven_anterior,2);
     vec_fec_ant(4):= add_months(v_fec_ven_anterior,3);

    --Trar la cantidad de años de Vencimiento--
    select fug_obt_pardinamico('VEN_TAR_DEB_FRAUDE', x.cod_modulo, x.cod_modalidad, x.cod_moneda, x.cod_oficina)
      into v_can_ven_tar_debito
      from ge_cuentas x
     where x.nro_cuenta = p_nro_cuenta;

    --Calcular la fecha inicial--
    v_ind_fec_valida := 'N';
    while v_ind_fec_valida = 'N' loop
      v_fec_inicial := last_day(add_months(v_fecha , (nvl(v_can_ven_tar_debito,4)*12)));
      vec_fec_cal(37) := v_fec_inicial;
      for v_indice in 1..36 loop
          v_fec_calculada := add_months(v_fec_inicial,v_indice*-1);
          --Validacion para que fecha de vencimiento no sea menor a la fecha actual--
          if v_fec_calculada <= v_fecha then
             raise_application_error(-20002, 'Error. Nro de años parametro VEN_TAR_DEB_FRAUDE no puede ser inferior a 36.'||sqlerrm);
          end if;
          vec_fec_cal(v_indice) := v_fec_calculada;
      end loop;
      --Toma Una fecha Randomica--
      v_nro_aleatoria:= trunc(DBMS_RANDOM.VALUE(1,38));
      v_fec_aleatoria := vec_fec_cal(v_nro_aleatoria);
      --Verifiacio de la fecha entre datos de la cuenta--
      v_ind_exi_fecha := 'N';
      select decode(nvl(count(*),0),0,'N','S')
        into v_ind_exi_fecha
        from ah_tar_debitos k
       where k.nro_cuenta = p_nro_cuenta
         and to_char(k.fec_vencimiento,'yyyymm') = to_char(v_fec_aleatoria,'yyyymm');
       if v_ind_exi_fecha = 'N' then
         for v_indice in 1..4 loop
             if to_char(v_fec_aleatoria,'yyyymm') = to_char(vec_fec_ant(v_indice),'yyyymm') then
                v_ind_exi_fecha := 'S';
                exit;
             end if;
         end loop;
       end if;
       if v_ind_exi_fecha = 'N' then
          v_ind_fec_valida := 'S';
          v_fec_ven_tar_debito := v_fec_aleatoria;
       end if;
    end loop;
  end if;
  return v_fec_ven_tar_debito;
exception
    when others then
      raise_application_error(-20002, 'Error en fua_obt_fec_ven_tar_debito: '||sqlerrm);
end;
/

