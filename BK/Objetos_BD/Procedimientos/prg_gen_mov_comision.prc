CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_COMISION IS
  --variables
  v_error          varchar2(1) := 'N';
  v_cod_modalidad  ge_modalidades.cod_modalidad%type;
  v_cod_modulo     ge_movimientos.cod_modulo%type;
  v_nro_secuencia  ge_movimientos.nro_secuencia%type := 0;
  v_hora           ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
  v_cod_moneda     ge_movimientos.cod_moneda%type;
  v_fec_actual     ge_movimientos.fecha%type := pag_cal.fu_obt_fec_actual(5); --Fecha de hoy;
  v_cod_ofi_origen ge_movimientos.cod_ofi_origen%type;
  v_cod_oficina    ge_movimientos.cod_oficina%type;
  v_monto          ge_movimientos.monto%type;
  r_gmovi          ge_movimientos%rowtype;
  --cursor
  cursor datos is
  	select a.referencia1, a.monto, a.fecha, a.rowid
      from ge_cob_servicios_tmp a;

  function lf_ver_cuentas(p_nro_cuenta ta_cta_tarjetas.nro_cuenta%type)
    return varchar2
    is
    v_existe varchar2(1);
    begin
      select distinct 'S'
        into v_existe
        from ta_cta_tarjetas a
       where a.nro_cuenta = p_nro_cuenta;
      return v_existe;
    exception
      when no_data_found then
        v_existe := 'N';
        return v_existe;
    end;

 function lf_ver_duplicado
   return varchar2
   is
   v_existe varchar2(1);
   begin
     select distinct 'S'-- count(*)
       into v_existe
       from ge_movimientos a
      where a.fecha = v_fec_actual--fecha_proceso
        and a.cod_tra_padre = 1213
        and a.cod_transaccion = 6030;
     return v_existe;
   exception
     when no_data_found then
        v_existe := 'N';
        return v_existe;
   end;

BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
  for dat in datos loop
    if lf_ver_cuentas(dat.referencia1) = 'N' then
      update ge_cob_servicios_tmp g
         set g.comentarios = 'La cuenta '||dat.referencia1||' no existe. '
       where g.rowid = dat.rowid;
       commit;
       v_error := 'S';
    end if;
  end loop;

  if v_error = 'S' then
    RAISE_APPLICATION_ERROR(-20000,'Archivo contiene errores. Verifique. ');
  end if;

  if lf_ver_duplicado = 'S' then
    RAISE_APPLICATION_ERROR(-20001,'Proceso ya ha sido generado para la fecha. ');
  end if;

  for dat in datos loop
    -- Modalidad, módulo y moneda de la cuenta(tarjeta).
    select cod_modalidad, cod_modulo, cod_moneda, cod_oficina
      into v_cod_modalidad, v_cod_modulo, v_cod_moneda, v_cod_oficina
      from ge_cuentas
     where nro_cuenta = dat.referencia1;
    --v_fec_actual     := pag_cal.fu_obt_fec_actual(v_cod_modulo); --Fecha de hoy

    if v_nro_secuencia > 990 then
      v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      v_nro_secuencia := 0;
    end if;
    v_nro_secuencia  := v_nro_secuencia + 1; --Aumento la secuencia.
    v_cod_ofi_origen := fug_obt_ofi_usuario(user);
    v_monto          := fug_obt_pardinamico('COB_COM_EXTRACTO',5);

    --Generar el movimiento por el credito.
    r_gmovi.cod_usuario     := user;
    r_gmovi.hora            := v_hora;
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.cod_modulo      := v_cod_modulo;
    r_gmovi.cod_modalidad   := v_cod_modalidad;
    r_gmovi.cod_oficina     := v_cod_oficina;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.fec_valor       := v_fec_actual;
    r_gmovi.cod_tra_padre   := 1213;
    r_gmovi.cod_mod_padre   := NVL(v_cod_modulo, 5);
    r_gmovi.cod_mad_padre   := NVL(v_cod_modalidad, 501);
    r_gmovi.cod_transaccion := 6030; --REIMPRESIÓN DE EXTRACTOS TDC
    r_gmovi.monto           := v_monto;
    r_gmovi.nro_documento   := dat.referencia1;
    r_gmovi.nro_documento2  := 1; --tip_saldo
    --r_gmovi.nro_documento3  := 2;
    r_gmovi.nro_cuenta      := dat.referencia1;
    r_gmovi.cod_ofi_origen  := v_cod_ofi_origen;
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.concepto        := 'REIMPRESIÓN DE EXTRACTOS TDC';
    r_gmovi.estado          := 'N'; -- Movimiento normal
    r_gmovi.reversado       := 'N';
    PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi);
  end loop;
END PRG_GEN_MOV_COMISION;
/

