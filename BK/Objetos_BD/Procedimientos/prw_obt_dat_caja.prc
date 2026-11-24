create or replace procedure it.prw_obt_dat_caja(p_cod_canal   varchar2,
                                                p_nro_caja    out cj_cajas.nro_caja%type,
                                                p_cod_oficina out cj_cajas.cod_oficina%type,
                                                p_cod_usuario out cj_cajas.cod_usuario%type,
                                                p_cod_error   out number,
                                                p_men_error   out varchar2) is
  v_est_caja       cj_cajas.estado%type;
  v_tip_caja       cj_cajas.tipo%type;
  v_cod_ofi_origen cj_cajas.cod_oficina%type;
  v_cod_usuario    cj_cajas.cod_usuario%type;
  v_nro_caja       cj_cajas.nro_caja%type;
  v_pro_correcto   number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                 0);
  v_err_sql        number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
begin
  p_cod_error := v_pro_correcto;
  begin
    select val_maximo
      into v_nro_caja
      from ba_cod_referencias
     where dominio = 'COD_CANAL_BW'
       and val_minimo = p_cod_canal;
  exception
    when others then
      v_nro_caja := 0;
  end;

  begin
    select estado, tipo, cod_oficina, cod_usuario
      into v_est_caja, v_tip_caja, v_cod_ofi_origen, v_cod_usuario
      from cj_cajas
     where nro_caja = v_nro_caja;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Error al buscar el nro de caja. ' || sqlerrm,
                            1,
                            4000);
  end;
  if v_tip_caja not in ('S') then
    -- tipo de caja no permitido
    p_cod_error := v_err_sql;
    p_men_error := 'Tipo de caja no valido para operaciones digitales.';
  end if;
  if v_est_caja <> 'A' then
    p_cod_error := v_err_sql;
    p_men_error := 'Estado de caja invalido.';
  end if;

  if p_cod_error = v_pro_correcto then
    p_nro_caja    := v_nro_caja;
    p_cod_oficina := v_cod_ofi_origen;
    p_cod_usuario := v_cod_usuario;
  end if;
exception
  when others then
    p_cod_error := v_err_sql;
    p_men_error := substr('Error al buscar los datos de la caja. ' ||
                          sqlerrm,
                          1,
                          4000);
end;
/

