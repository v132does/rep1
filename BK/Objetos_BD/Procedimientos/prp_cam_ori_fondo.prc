CREATE OR REPLACE PROCEDURE IT."PRP_CAM_ORI_FONDO" ( p_nro_cuenta   in VARCHAR2,
                                           p_cod_ori_fondo_nvo in NUMBER,
                                           p_por_ori_fondo_nvo in number ,
                                           p_cod_ofi_origen in number)
 IS
   --- Variables auxiliares
   r_gmovi ge_movimientos%rowtype;
   v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(6);
   r_gprestamos pr_cta_prestamos%rowtype;
   v_redondeo number;
   v_monto number;
   v_ori_fon_propio pr_cta_prestamos.cod_ori_fondo%type;
BEGIN
    if p_cod_ori_fondo_nvo is null and p_por_ori_fondo_nvo is null then
       raise_application_error(-20000,'No puede actualizar a null Origen y Porcentaje de Fondos');
    end if;

    begin
      select *
        into r_gprestamos
        from pr_cta_prestamos
       where nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        raise_application_error(-20000,'Cta. de Préstamo inexistente '||p_nro_cuenta);
      when others then
        raise_application_error(-20000,sqlerrm || '- Al recup. cta préstamo: '||p_nro_cuenta);
    end;
    -- calcular monto
    v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',  null, null,r_gprestamos.cod_moneda);
    v_ori_fon_propio := fug_obt_pardinamico('COD_ORI_FON_DESEMB',NULL,NULL,r_gprestamos.cod_moneda,null,null);
    if p_por_ori_fondo_nvo > 0 and p_por_ori_fondo_nvo <= 100 then
       v_monto := round(r_gprestamos.sal_capital * p_por_ori_fondo_nvo / 100,v_redondeo); --sólo el porcentaje
    end if;

    r_gmovi.concepto := 'Cambio Origen de Fondos '||r_gprestamos.cod_ori_fondo||' a '||p_cod_ori_fondo_nvo;

    if p_cod_ori_fondo_nvo = v_ori_fon_propio then
      r_gmovi.concepto := 'Re-traslado a Fondos Propios - '||r_gprestamos.cod_ori_fondo||' a '||p_cod_ori_fondo_nvo;
      --es fondos propios, es una reversión, debe tomar todo el porcentaje que había enviado a AFD
      if r_gprestamos.por_ori_fondo <> p_por_ori_fondo_nvo then
        raise_application_error(-20000,'Debe trasladar el porcentaje completo de AFD a Fondos Propios, no puede ser parcial.');
      end if;
    end if;

    --- Actualiar préstamo
    update pr_cta_prestamos
       set cod_ori_fondo = nvl(p_cod_ori_fondo_nvo, cod_ori_fondo),
           por_ori_fondo = decode(p_cod_ori_fondo_nvo,v_ori_fon_propio,100,nvl(p_por_ori_fondo_nvo, por_ori_fondo))
     where nro_cuenta = p_nro_cuenta;

   r_gmovi.nro_secuencia      := 1;
   r_gmovi.cod_usuario        := user;
   r_gmovi.hora               := to_char(sysdate,'HH24:MI:SS');
   r_gmovi.fecha              := pag_cal.fu_obt_fec_actual(6);
   r_gmovi.cod_modulo         := 6;
   r_gmovi.cod_modalidad      := r_gprestamos.cod_modalidad;
   r_gmovi.cod_oficina        := r_gprestamos.cod_oficina;
   r_gmovi.nro_cuenta         := p_nro_cuenta;
   r_gmovi.cod_moneda         := r_gprestamos.cod_moneda;
   r_gmovi.cod_tra_padre      := 120; --cambio de origen de fondos
   r_gmovi.cod_transaccion    := fup_obt_tra_ori_fondo(p_cod_ori_fondo_nvo,r_gprestamos.cod_moneda,'A'); --transacc de desembolso
   r_gmovi.monto              := v_monto;
   r_gmovi.fec_valor          := r_gmovi.fecha;
   r_gmovi.emi_aviso          := 'S';
   r_gmovi.reversado          := 'N';
   r_gmovi.protegido          := 'N';
   r_gmovi.estado             := 'N';
   r_gmovi.cod_ofi_origen     := p_cod_ofi_origen;
   r_gmovi.cod_mod_padre      := 6;
   r_gmovi.cod_mad_padre      := r_gprestamos.cod_modalidad;
   pag_gen.pr_ins_ge_movimiento(r_gmovi);
END;
/

