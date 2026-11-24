CREATE OR REPLACE PROCEDURE IT.PRP_INS_DES_PRESTAMOS(p_nro_cuenta in varchar2,
                                                  p_cod_tra_padre in number,
                                                  p_mora in number,
                                                  p_mor_interes in number,
                                                  p_mor_int_ade in number,
                                                  p_punitorio in number,
                                                  p_cargo in number,
                                                  p_impuesto in number,
                                                  p_observacion in varchar2) is

   --Proyecto SDRES4COVI-6 / Resolucion 4 BCP----29.04.20-----
   --Funcionalidad: Insertar descuentos para prestamos-------
   cursor c_descuentos is
   select pr.nro_cuenta, pr.cod_oficina, nvl(pr.mto_capital,0) mto_capital, pr.nro_solicitud, pr.cod_moneda,
          nvl(pr.sal_capital,0) sal_capital, nvl(pr.val_int_devengar,0) val_int_devengar, nvl(pr.dev_suspenso,0) dev_suspenso,
          pr.estado, pr.tipo, pr.tip_interes, pr.tip_renovacion, pr.cod_modalidad, nvl(pr.dev_no_cobrado,0) dev_no_cobrado
     from pr_cta_prestamos pr
    where pr.nro_cuenta = P_NRO_CUENTA
      and pr.estado <> 'N';

   -- Variables de tipo registro.
   r_gauto           ge_autorizaciones%rowtype;
   v_fecha           date;
   v_cuenta          pr_cta_prestamos.nro_cuenta%type;
   v_cod_transaccion ge_movimientos.cod_transaccion%type;
   v_mora            pr_cuotas.sal_interes%type;
   v_mor_interes     pr_cuotas.sal_interes%type;
   v_mor_int_ade     pr_cuotas.sal_interes%type;
   v_punitorio       pr_cuotas.sal_interes%type;
   v_cargo           pr_cuotas.sal_interes%type;
   v_impuesto        pr_cuotas.sal_interes%type;

  -- Procedimientos Internos.
  procedure lp_ins_autorizacion(p_gauto ge_autorizaciones%rowtype) is
  begin
    insert into ge_autorizaciones
        (cod_autorizacion, nro_cuenta, cod_tra_padre,
         cod_mod_padre, cod_mad_padre, cod_transaccion,
         cod_modulo, cod_modalidad, valor, fec_vencimiento,
         cod_usu_autorizador, observacion)
     values
        (s_cod_autorizacion.nextval, p_gauto.nro_cuenta, p_gauto.cod_tra_padre,
         p_gauto.cod_mod_padre, p_gauto.cod_mad_padre, p_gauto.cod_transaccion,
         p_gauto.cod_modulo, p_gauto.cod_modalidad, p_gauto.valor, p_gauto.fec_vencimiento,
         p_gauto.cod_usu_autorizador, p_gauto.observacion);
  exception
    when others then
       raise_application_error(-20005, 'Error al insertar autorizacion: '||sqlerrm);
  end;

BEGIN
   --Carga de variables--
   v_fecha := pag_cal.fu_obt_fec_actual(6);
   
   --Validacion de cuenta--
   BEGIN
   select x.nro_cuenta
     into v_cuenta
     from pr_cta_prestamos x
    where x.nro_cuenta = p_nro_cuenta;
   
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       v_cuenta := NULL;
       raise_application_error(-20000, 'Error. Cuenta '||p_nro_cuenta||' No existe. Verifique.');
     WHEN OTHERS THEN
       v_cuenta := NULL;
       raise_application_error(-20000, 'Error. Al traer datos de Cuenta '||p_nro_cuenta||'-'||sqlerrm);
   END;
   
   -- Cursor.
   for des in c_descuentos loop      
      --1) Mora s/ Capital--
      v_mora := p_mora;      
      v_cod_transaccion := null;
      if nvl(v_mora,0) <> 0 then --Mora sobre capital
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MO', des.estado, des.tipo, des.tip_interes, des.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := des.nro_cuenta;
         r_gauto.cod_tra_padre       := p_cod_tra_padre;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := des.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := des.cod_modalidad;
         r_gauto.valor               := nvl(v_mora,0);
         r_gauto.fec_vencimiento     := v_fecha;
         r_gauto.observacion         := substr(p_observacion,1,1000);
         --- insertar ge_autorizaciones
         lp_ins_autorizacion(r_gauto);
      end if;
      
      --2) Mora s/ interes--
      v_mor_interes := p_mor_interes;
      v_cod_transaccion := null;
      if nvl(v_mor_interes,0) <> 0 then --Mora sobre interes
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MI', des.estado, des.tipo, des.tip_interes, des.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := des.nro_cuenta;
         r_gauto.cod_tra_padre       := p_cod_tra_padre;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := des.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := des.cod_modalidad;
         r_gauto.valor               := nvl(v_mor_interes,0);
         r_gauto.fec_vencimiento     := v_fecha;
         r_gauto.observacion         := substr(p_observacion,1,1000);
         --- insertar ge_autorizaciones
         lp_ins_autorizacion(r_gauto);
      end if;
      
      --3) Mora s/ Interes adelantado--
      v_mor_int_ade := p_mor_int_ade;
      v_cod_transaccion := null;
      if nvl(v_mor_int_ade,0) <> 0 then --Mora sobre interes adelantado
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MA', des.estado, des.tipo, des.tip_interes, des.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := des.nro_cuenta;
         r_gauto.cod_tra_padre       := p_cod_tra_padre;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := des.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := des.cod_modalidad;
         r_gauto.valor               := nvl(v_mor_int_ade,0);
         r_gauto.fec_vencimiento     := v_fecha;
         r_gauto.observacion         := substr(p_observacion,1,1000);
         --- insertar ge_autorizaciones
         lp_ins_autorizacion(r_gauto);
      end if;
      
      --4) Punitorio--
      v_punitorio := p_punitorio;
      v_cod_transaccion := null;
      if nvl(v_punitorio,0) <> 0 then --Punitorio
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('PU', des.estado, des.tipo, des.tip_interes, des.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := des.nro_cuenta;
         r_gauto.cod_tra_padre       := p_cod_tra_padre;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := des.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := des.cod_modalidad;
         r_gauto.valor               := nvl(v_punitorio,0);
         r_gauto.fec_vencimiento     := v_fecha;
         r_gauto.observacion         := substr(p_observacion,1,1000);
         --- insertar ge_autorizaciones
         lp_ins_autorizacion(r_gauto);
      end if;
      
      --5) Cargos--
      v_cargo := p_cargo;
      v_cod_transaccion := null;
      if nvl(v_cargo,0) <> 0 then --Cargos
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('CG', des.estado, des.tipo, des.tip_interes, des.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := des.nro_cuenta;
         r_gauto.cod_tra_padre       := p_cod_tra_padre;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := des.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := des.cod_modalidad;
         r_gauto.valor               := nvl(v_cargo,0);
         r_gauto.fec_vencimiento     := v_fecha;
         r_gauto.observacion         := substr(p_observacion,1,1000);
         --- insertar ge_autorizaciones
         lp_ins_autorizacion(r_gauto);
      end if;
      
      --6) Impuestos--
      v_impuesto := p_impuesto;
      v_cod_transaccion := null;
      if nvl(v_impuesto,0) <> 0 then --Impuestos
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('IM', des.estado, des.tipo, des.tip_interes, des.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := des.nro_cuenta;
         r_gauto.cod_tra_padre       := p_cod_tra_padre;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := des.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := des.cod_modalidad;
         r_gauto.valor               := nvl(v_impuesto,0);
         r_gauto.fec_vencimiento     := v_fecha;
         r_gauto.observacion         := substr(p_observacion,1,1000);
         --- insertar ge_autorizaciones
         lp_ins_autorizacion(r_gauto);
      end if;      
   end loop;

EXCEPTION
   WHEN OTHERS THEN
        raise_application_error(-20000, 'Error em PRP_INS_DES_PRESTAMOS :'||sqlerrm);
END PRP_INS_DES_PRESTAMOS;
/

