create or replace PROCEDURE    IT.PRP_ACT_GARANTIA
 IS
cursor garantia is
       select prp.fec_inicio, prp.nro_cuenta, nvl(prp.sal_capital,0),
              nvl(prp.dev_no_cobrado,0),psg.cod_garantia, psg.nro_garantia,
              prp.cod_moneda
         from pr_cta_prestamos prp,
              pr_cta_garantias psg,
              pr_gar_tipos     pgt
        where prp.nro_cuenta = psg.nro_cuenta
          and prp.estado <> 'N'
          and psg.cod_garantia = pgt.cod_garantia
          and pgt.por_bco_central is not null
          and psg.nro_garantia in (select nro_garantia
                                   from pr_garantias
                                  where nro_garantia = psg.nro_garantia
                                    and estado = 'C' )
       order by psg.nro_garantia, psg.cod_garantia, prp.fec_inicio, nvl(pgt.pri_aplicacion,0);--gar reales
  --
  v_fchaini  date;                                  -- fecha de inicio del prestamo
  v_nrcuent  pr_cta_prestamos.nro_cuenta%type;      -- numero de cuenta
  v_slcapol  pr_cta_prestamos.sal_capital%type;     -- saldo de capital
  v_vldevnc  pr_cta_prestamos.dev_no_cobrado%type;  -- devengado no cobrado
  v_cdgaran  pr_cta_garantias.cod_garantia%type;    -- codigo de tipo de garantia
  v_nrgaran  pr_cta_garantias.nro_garantia%type;    -- nro. de garantia
  v_cdtring  pr_gar_tipos.cod_transaccion1%type;    -- transaccion ingreso de garantia
  v_cdtrcan  pr_gar_tipos.cod_transaccion2%type;    -- transaccion cancelacion de garantia
  v_porcbcp  pr_gar_tipos.por_bco_central%type;     -- porc s/bcp para el calculo de la garcompu
  v_computa  pr_gar_tipos.computable%type;          -- indica si la garantia es computable
  v_antgara  pr_cta_garantias.nro_garantia%type:= 0;-- codigo garantia anterior
  v_moneda   ba_monedas.cod_moneda%type;            -- moneda del prestamo
  v_monegar  ba_monedas.cod_moneda%type;            -- moneda de la garantia
  v_monetas  ba_monedas.cod_moneda%type;            -- moneda de la tasacion
  v_vlgaran  pr_garantias.valor%type;               --valor de la garantia
  v_vltasac  pr_garantias.val_tasacion%type;        --valor de tasacion de la garantia
  v_vlcompu  pr_garantias.valor%type;               --valor computable de la garantia
  v_vlmoncu  pr_garantias.valor%type;               --monto total de prest cubierto p/garantia
                                                    --en la moneda de la garantia
  v_totdeuda pr_garantias.valor%type;               --total de deuda del cliente
  v_moneloc  ba_monedas.cod_moneda%type;
  v_fcdehoy  date;
  v_nro_secuencia ge_movimientos.nro_secuencia%type; -- nro de secuencia
  v_hora          ge_movimientos.hora%type;
  v_cod_usuario   ba_usuarios.cod_usuario%type;
  v_cod_oficina   ba_oficinas.cod_oficina%type;


--Obtener tipo de garantia
procedure lp_obt_tipo_garantia (p_cdgaran in number,
                                p_cdtring in out number,
                                p_cdtrcan in out number,
                                p_porcbcp in out number,
                                p_computa in out varchar2 ) is
begin
  select cod_transaccion1,cod_transaccion2,por_bco_central, computable
    into p_cdtring, p_cdtrcan, p_porcbcp, p_computa
    from pr_gar_tipos
   where cod_garantia = p_cdgaran;
exception
  when no_data_found then
    raise_application_error(-20000,'Tipo de garantia no existe');
  when others then
    raise_application_error(-20000,sqlerrm);
end;

--Obtener datos de la Garantia
procedure lp_obt_datos_garantia(p_nrgaran in number,
                                p_cdgaran in number,
                                p_monegar in out varchar2,
                                p_vlgaran in out number,
                                p_monetas in out varchar2,
                                p_vltasac in out number  ) is
begin
 select cod_moneda, nvl(valor,0),nvl(val_tasacion,0), cod_mon_tasacion
   into p_monegar, p_vlgaran, p_vltasac, p_monetas
  from pr_garantias
 where nro_garantia = p_nrgaran
   and cod_garantia = p_cdgaran;
exception
when no_data_found then
   raise_application_error(-20000,'Garantia '||to_char(p_nrgaran)||' no existe en PR_GARANTIAS ');
when others then
   raise_application_error(-20000,sqlerrm);
end;
--Calcular valor computable
function  lp_cal_valor_computable
                                  (p_cdgaran in number,
                                   p_porcbcp in number,
                                   p_vlgaran in number,
                                   p_vltasac in number,
                                   p_computa in varchar2 ) return number is
v_retorno number(18,2);
begin
-- calcula el valor computable
   if p_computa = 'S' then
       if p_vltasac > 0 then
          --- Si posee valor de tasacion ese es el que computa
          v_retorno := p_vltasac * nvl(p_porcbcp,0) / 100;
       else
          --- El % computable se aplica solo sobre la tasación
          --- El valor de la garantia es siempre sobre el 100%
          v_retorno := p_vlgaran;
          ---v_retorno := p_vlgaran * nvl(p_porcbcp,0) / 100;
       end if;
   else
       v_retorno := 0; --- No es computable
   end if;
   return v_retorno;
end;
--Pasar a moneda de la garantia
function  lf_conv_moneda_garantia  (p_cdmonpr in varchar2,
                                    p_cdmonga in varchar2,
                                    p_importe in number   )
                        return number is
begin
    if p_cdmonpr = p_cdmonga then
       return p_importe;
    elsif p_cdmonpr = v_moneloc then
       return (p_importe   /
               PAG_GEN.FU_OBT_COTIZACION(p_cdmonga,v_fcdehoy));
    elsif p_cdmonga = v_moneloc then
       return (p_importe *
               PAG_GEN.FU_OBT_COTIZACION(p_cdmonpr,v_fcdehoy));
    else
       return (p_importe *
               PAG_GEN.FU_OBT_COTIZACION(p_cdmonpr,v_fcdehoy) /
               PAG_GEN.FU_OBT_COTIZACION(p_cdmonga,v_fcdehoy));
    end if;
exception
  when others then
   raise_application_error(-20000,'Al convertir saldos a la moneda de garantia');
end;

--Obtener saldo capital de las solititudes pendientes
procedure lp_obt_capital(p_nrgaran in number,
                          p_cdgaran in number,
                          p_sal_capital in out number) is

begin
  select nvl(sum(pre.tot_prestamo),0)sal_capital
    into p_sal_capital
    from pr_garantias gar,
         pr_sol_garantias cta,
         pr_solicitudes pre,
         ge_modalidades mad,
         pr_gar_tipos  pgt
   where gar.nro_garantia = p_nrgaran
     and gar.cod_garantia = p_cdgaran
     and gar.nro_garantia = cta.nro_garantia
     and gar.cod_garantia = cta.cod_garantia
     and cta.nro_solicitud = pre.nro_solicitud
     and pre.cod_modulo = mad.cod_modulo
     and pre.cod_modalidad = mad.cod_modalidad
     and pre.estado in ('S','L')
     and cta.cod_garantia = pgt.cod_garantia
     and pgt.por_bco_central is not null
     and cta.nro_garantia in (select nro_garantia
                                from pr_garantias
                               where nro_garantia = cta.nro_garantia
                                 and estado = 'C' );
end;

PROCEDURE lp_actualizar IS
begin
   if garantia%isopen then
     close garantia;
   end if;
   open garantia;
   loop
     fetch garantia
      into v_fchaini, v_nrcuent, v_slcapol, v_vldevnc, v_cdgaran,
           v_nrgaran, v_moneda;
     exit when garantia%notfound;
     if v_antgara <> v_nrgaran then
        lp_obt_tipo_garantia(v_cdgaran, v_cdtring,
                             v_cdtrcan, v_porcbcp, v_computa);
        lp_obt_datos_garantia(v_nrgaran, v_cdgaran, v_monegar,
                              v_vlgaran, v_monetas, v_vltasac);
			      
        -- Las FOGAPY debe computar por el saldo del capital por el porc definido en pr_gar_tipos                     
        if instr(fug_obt_pardinamico('COD_GAR_FOGAPY'),v_cdgaran) > 0 then 
           v_vlcompu := nvl(v_slcapol,0) * v_porcbcp / 100;
        else
        --- Recupera el valor computable de la garantia
           v_vlcompu := pap_gar.FU_OBT_VAL_COMPUTABLE(v_nrgaran);
        end  if;
        v_antgara := v_nrgaran;
--      v_vlmoncu := 0;
        lp_obt_capital(v_nrgaran, v_cdgaran, v_vlmoncu);
     end if;
     if v_monegar <> v_moneda then
        --- Convertir a la moneda del prestamo el valor computable
        v_vlcompu := PAG_GEN.FU_CON_MON_A_MONEDA(v_monegar, v_moneda, v_vlcompu);
        v_vlmoncu := PAG_GEN.FU_CON_MON_A_MONEDA(v_monegar, v_moneda, v_vlmoncu);
        v_monegar := v_moneda;
     end if;
     if v_vlcompu - v_vlmoncu > 0 then
        --- El monto aplicado debe ir en la moneda del prestamo
        v_totdeuda := v_slcapol + v_vldevnc;
        if v_vlcompu - v_vlmoncu > v_totdeuda then
           update pr_cta_garantias
              set mto_apl_computable  = v_totdeuda
            where nro_garantia  = v_nrgaran
              and nro_cuenta = v_nrcuent;
           v_vlmoncu := v_vlmoncu + v_totdeuda;
        else
           update pr_cta_garantias
              set mto_apl_computable = v_vlcompu - v_vlmoncu
            where nro_garantia = v_nrgaran
              and nro_cuenta = v_nrcuent;
           v_vlmoncu := v_vlmoncu + (v_vlcompu - v_vlmoncu);
        end if;
     else
        update pr_cta_garantias
           set mto_apl_computable  = 0
         where nro_garantia  = v_nrgaran
              and nro_cuenta = v_nrcuent;
     end if;
   end loop; -- de caja --
   if garantia%isopen then
     close garantia;
   end if;
exception
  when no_data_found then
    raise_application_error(-20000,'No existe datos en el archivo verifique');
end;
--Genera movimiento
procedure lp_gen_movimiento
  (p_nrgaran in number,   p_cdtrcan in number,
   p_cdmoned in varchar2, p_vlgaran in number ) is

   v_cdtranp   ge_movimientos.cod_transaccion%type;
   v_concepto  ge_movimientos.concepto%type;
begin
  v_nro_secuencia := to_number(v_nro_secuencia) + 1;
  if p_cdtrcan = 951 then -- cont.de la linea de credito hipotecaria
     v_cdtranp := 951;
     v_concepto := 'Mov.lineas de credito hipotecaria';
  else
     v_cdtranp := 950;    -- contabilizacion de la garantia (valor)
     v_concepto := 'Vencimiento de garant.reales';
  end if;
  insert into ge_movimientos
     (cod_usuario, hora, nro_secuencia, cod_modulo,
      cod_modalidad, cod_oficina,cod_tra_padre, cod_transaccion, fecha,
      fec_valor, cod_moneda, monto,estado, reversado,
      protegido, emi_aviso,cod_mod_padre, cod_mad_padre,cod_ofi_origen,
      nro_documento,concepto)
   values
     (v_cod_usuario, v_hora, v_nro_secuencia,6 ,
      61, v_cod_oficina, v_cdtranp, p_cdtrcan, v_fcdehoy,
      v_fcdehoy, p_cdmoned, p_vlgaran,'N','N',
      'N','N', 6, 61,v_cod_oficina, p_nrgaran,v_concepto);
exception
   when others then
     raise_application_error(-20000,'Al generar el .ge_movimientos '||sqlerrm);
end;
--PASAR GAR.REAL A VENCIDA
procedure lp_pro_gar_real is

v_nro_garantia     pr_garantias.nro_garantia%type;
v_cod_garantia     pr_garantias.cod_garantia%type;
v_nom_tab_anexa    pr_gar_tipos.nom_tab_anexa%type;
v_valor            pr_garantias.valor%type;
v_cod_moneda       pr_garantias.cod_moneda%type;
v_cod_persona      pr_garantias.cod_persona%type;
v_cod_transaccion1 pr_gar_tipos.cod_transaccion1%type;
v_cod_transaccion2 pr_gar_tipos.cod_transaccion2%type;
v_por_bco_central  pr_gar_tipos.por_bco_central%type;

cursor garantia is
   select pr_garantias.nro_garantia, pr_garantias.cod_garantia,
          pr_garantias.valor, pr_garantias.cod_moneda, pr_garantias.cod_persona
     from pr_garantias, pr_gar_tipos
    where pr_garantias.fec_vencimiento <= v_fcdehoy
      and pr_garantias.cod_garantia = pr_gar_tipos.cod_garantia
      and pr_gar_tipos.por_bco_central is not null
      and pr_garantias.estado = 'C' -- FIELDESK-165412: solo confirmadas (antes C o T)
   union
   select pr_garantias.nro_garantia, pr_garantias.cod_garantia, 
          pr_garantias.valor, pr_garantias.cod_moneda, pr_garantias.cod_persona
     from pr_garantias, pr_gar_tipos, pr_gar_hipotecarias
    where pr_garantias.nro_garantia = pr_gar_hipotecarias.nro_garantia
      and pr_gar_hipotecarias.fec_vencimiento <= v_fcdehoy
      and pr_garantias.cod_garantia = pr_gar_tipos.cod_garantia
      and pr_gar_tipos.por_bco_central is not null
      and pr_garantias.estado = 'C' -- FIELDESK-165412: solo confirmadas (antes C o T)
   union
   select pr_garantias.nro_garantia, pr_garantias.cod_garantia, 
          pr_garantias.valor, pr_garantias.cod_moneda, pr_garantias.cod_persona
     from pr_garantias, pr_gar_tipos, pr_gar_vehiculos
    where pr_garantias.nro_garantia = pr_gar_vehiculos.nro_garantia
      and pr_gar_vehiculos.fec_vencimiento <= v_fcdehoy
      and pr_garantias.cod_garantia = pr_gar_tipos.cod_garantia
      and pr_gar_tipos.por_bco_central is not null
      and pr_garantias.estado = 'C' -- FIELDESK-165412: solo confirmadas (antes C o T)
   -- FIELDESK-165412: se quita la rama de PR_GAR_DOCUMENTOS (FOGAPY/FOGAVI) y pr_gar_cash. Esas garantias
   -- no tienen tasacion y su fec_vencimiento no es un vencimiento de tasacion.
   union
   select pr_garantias.nro_garantia, pr_garantias.cod_garantia, 
          pr_garantias.valor, pr_garantias.cod_moneda, pr_garantias.cod_persona
     from pr_garantias, pr_gar_tipos, pr_gar_fideicomiso
    where pr_garantias.nro_garantia = pr_gar_fideicomiso.nro_garantia
      and pr_gar_fideicomiso.fec_vencimiento <= v_fcdehoy
      and pr_garantias.cod_garantia = pr_gar_tipos.cod_garantia
      and pr_gar_tipos.por_bco_central is not null
      and pr_garantias.estado = 'C' -- FIELDESK-165412: solo confirmadas (antes C o T)
   union
   select pr_garantias.nro_garantia, pr_garantias.cod_garantia,
          pr_garantias.valor, pr_garantias.cod_moneda, pr_garantias.cod_persona
     from pr_garantias, pr_gar_tipos
    where pr_garantias.fec_vencimiento <= v_fcdehoy
      and pr_garantias.cod_garantia = pr_gar_tipos.cod_garantia
      and instr(','||fug_obt_pardinamico('GAR_VEN_NOCOMPUTABLES')||',' ,  ','||pr_gar_tipos.cod_garantia||',') > 0
      and pr_garantias.estado = 'C'; -- FIELDESK-165412: solo confirmadas (antes C o T)
begin
   if garantia%isopen then
      close garantia;
   end if;
   open garantia;
   loop
       fetch garantia into v_nro_garantia, v_cod_garantia, v_valor, 
                           v_cod_moneda, v_cod_persona;
       exit when garantia%notfound;
       -- Nombre de Tabla Correspondiente a la Garantía
       v_nom_tab_anexa := fup_obt_nom_tab_anexa(v_cod_garantia);
       /* actualizar datos en la cabecera */
        begin
          update pr_garantias
             set estado = 'V'
           where nro_garantia = v_nro_garantia
             and cod_garantia = v_cod_garantia;
        exception
          when others then
            raise_application_error(-20001,'Al cambiar a vencida en pr_garantias Nro.'
                    ||to_char(v_nro_garantia)||sqlerrm);
        end;
        lp_obt_tipo_garantia(v_cod_garantia, v_cod_transaccion1,
                              v_cod_transaccion2, v_por_bco_central,v_computa );

        v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
        --lp_gen_movimiento(v_nro_garantia, v_cod_transaccion2, v_cod_moneda, v_valor);
        --if v_cod_garantia = 3 then
        if v_nom_tab_anexa = 'PR_GAR_HIPOTECARIAS' then
          begin
            update cr_per_propiedades
               set hipotecado = 'N'
             where cod_persona = v_cod_persona
               and exists (select pr_gar_hipotecarias.nro_finca
                                 from pr_gar_hipotecarias
                                where pr_gar_hipotecarias.nro_finca = cr_per_propiedades.nro_finca
                                  and pr_gar_hipotecarias.nro_garantia = v_nro_garantia);
          exception
            when others then
               raise_application_error(-20002,'Error: Al actualizar propiedades_x_persona ');
          end;
        --elsif v_cod_garantia = 4 then
        elsif v_nom_tab_anexa = 'PR_GAR_VEHICULOS' then
          begin
            update cr_per_vehiculos
               set prendado = 'N'
             where cod_persona = v_cod_persona
               and exists (select pr_gar_vehiculos.cod_marca
                                   from pr_gar_vehiculos
                                  where pr_gar_vehiculos.cod_marca = cr_per_vehiculos.cod_marca
                                    and pr_gar_vehiculos.modelo = cr_per_vehiculos.modelo
                                    and pr_gar_vehiculos.ano = cr_per_vehiculos.ano
                                    and pr_gar_vehiculos.nro_garantia = v_nro_garantia );
          exception
            when others then
               raise_application_error(-20003,'Error: Al actualizar vehiculos_x_persona');
          end;
        end if;
  end loop; -- de caja --
  if garantia%isopen then
     close garantia;
  end if;
exception
    when no_data_found then
       raise_application_error(-20004,'No existe datos en el archivo PR_GARANTIAS');
end;
--Inactivar garantias reales
procedure lp_ina_gar_reales is
cursor garantia is
     select pr_garantias.nro_garantia, pr_garantias.cod_garantia, pr_garantias.fec_ult_utilizacion
       from pr_garantias
      where pr_garantias.estado = 'C' -- confirmada
        and pr_garantias.cod_garantia not in (1,2)
        and not exists (select '1'
                          from gv_cta_garantias
                         where gv_cta_garantias.nro_garantia = pr_garantias.nro_garantia
                           and gv_cta_garantias.nro_cuenta is not null);



v_nro_garantia pr_garantias.nro_garantia%type;
v_cod_garantia pr_garantias.cod_garantia%type;
v_fec_ult_utilizacion pr_garantias.fec_ult_utilizacion%type;
v_fec_actual date;
begin
  v_fec_actual := pag_cal.fu_obt_fec_actual(6);


  open garantia;
  loop
      fetch garantia into v_nro_garantia, v_cod_garantia, v_fec_ult_utilizacion;
      exit when garantia%notfound;
      /* actualizar datos en la cabecera */
      If v_fec_ult_utilizacion is null then
          begin
              update pr_garantias
                 set fec_ult_utilizacion = v_fec_actual
               where nro_garantia = v_nro_garantia
                 and cod_garantia = v_cod_garantia;
          exception
             when others then
               raise_application_error(-20000,'Error: Al cambiar a inactiva en pr_garantias Nro.'
                       ||to_char(v_nro_garantia)||sqlerrm);
          end;
      Else
        If v_fec_actual - v_fec_ult_utilizacion >= fug_obt_pardinamico('DIA_INA_GARANTIA') then
          begin
              update pr_garantias
                 set estado = 'T'
               where nro_garantia = v_nro_garantia
                 and cod_garantia = v_cod_garantia;
          exception
             when others then
               raise_application_error(-20000,'Error: Al cambiar a inactiva en pr_garantias Nro.'
                       ||to_char(v_nro_garantia)||sqlerrm);
          end;
        End If;
      end if;
  end loop; -- de garantia --
  if garantia%isopen then
     close garantia;
  end if;
exception
    when no_data_found then
      raise_application_error(-20000, 'No existe datos en el archivo PR_GARANTIAS');
end;
--Actualizar Capital devengado cobrado x linea de credito
procedure lp_act_capital   is
cursor garantia is
     select pr_solicitudes.fec_inicio, pr_cta_prestamos.nro_cuenta, nvl(pr_cta_prestamos.sal_capital,0), nvl(pr_cta_prestamos.dev_no_cobrado,0),
            pr_cta_garantias.cod_garantia, pr_cta_garantias.nro_garantia, pr_solicitudes.cod_moneda, pr_garantias.cod_moneda,
            nvl(pr_garantias.valor,0), nvl(pr_garantias.val_tasacion,0), pr_cta_prestamos.mto_lin_aplicado
       from pr_cta_prestamos, pr_solicitudes, pr_cta_garantias, pr_gar_tipos, pr_garantias
      where pr_cta_prestamos.nro_solicitud = pr_solicitudes.nro_solicitud
        and pr_cta_prestamos.nro_cuenta = pr_cta_garantias.nro_cuenta
        and pr_cta_prestamos.estado <> 'N'
        and pr_cta_garantias.cod_garantia = pr_gar_tipos.cod_garantia
        and pr_gar_tipos.por_bco_central is not null
        and pr_cta_garantias.nro_garantia = pr_garantias.nro_garantia
        and pr_garantias.estado = 'C'  --confirmada
--        and pr_garantias.cod_garantia =  3   --hipotecaria
        and pr_gar_tipos.nom_tab_anexa = 'PR_GAR_HIPOTECARIAS'
        and pr_garantias.tipo = 'A'  --abierta
     order by pr_garantias.cod_moneda, pr_cta_garantias.cod_garantia, pr_cta_garantias.nro_garantia, pr_solicitudes.fec_inicio;
--
v_fec_incio        pr_solicitudes.fec_inicio%type;         -- fecha de inicio del prestamo
v_nro_cuenta       pr_cta_prestamos.nro_cuenta%type;   -- numero de propuesta
v_sal_capital      pr_cta_prestamos.sal_capital%type; -- saldo de capital
v_dev_no_cobrado   pr_cta_prestamos.dev_no_cobrado%type; -- devengado no cobrado
v_cod_garantia     pr_cta_garantias.cod_garantia%type;    -- codigo de tipo de garantia
v_nro_garantia     pr_cta_garantias.nro_garantia%type;    -- nro. de garantia
v_cdtring          pr_gar_tipos.cod_transaccion1%type;    -- transaccion ingreso de garantia
v_cdtrcan          pr_gar_tipos.cod_transaccion1%type;    -- transaccion cancelacion de garantia
v_porcbcp          pr_gar_tipos.por_bco_central%type;    -- porc s/bcp para el calculo de la garcompu
v_ant_garantia     pr_cta_garantias.nro_garantia%type := 0; -- codigo garantia anterior
v_cod_moneda       pr_solicitudes.cod_moneda%type;   -- moneda del prestamo
v_cod_mon_gar      pr_solicitudes.cod_moneda%type;   -- moneda de la garantia
v_ant_moneda       pr_solicitudes.cod_moneda%type:= null; -- moneda ant. de la garantia
v_val_garantia     pr_garantias.valor%type; --valor de la garantia
v_val_garantia_ant number(18,2); --valor de la garantia ant
v_val_tasacion     pr_garantias.val_tasacion%type; --valor de tasacion de la garantia
v_sal_linea        pr_lin_aplicaciones.mto_aplicado%type; --saldo de la linea de credito
v_sal_linea_ant    pr_lin_aplicaciones.mto_aplicado%type; --saldo de la linea de credito ant
v_vlmoncu          number(18,2); --monto total de prest cubierto p/garantia en la moneda de la garantia
v_totdeuda         number(18,2); --total de deuda del cliente
v_difasie          number(18,2); --diferencia p/realizar asiento contable
v_ttlcrmon         number(18,2); --total linea de credito por moneda p/contab.
v_cod_persona      ba_usuarios.cod_usuario%type;
begin
   if garantia%isopen then
      close garantia;
   end if;
   open garantia;
   loop
       fetch garantia
        into v_fec_incio, v_nro_cuenta, v_sal_capital, v_dev_no_cobrado, v_cod_garantia,
             v_nro_garantia, v_cod_moneda, v_cod_mon_gar, v_val_garantia, v_val_tasacion,
             v_sal_linea;
       exit when garantia%notfound;
       --
       if v_ant_garantia <> v_nro_garantia then
          if v_ant_garantia        <> 0 and
             nvl(v_vlmoncu,0) <> 0 then
             v_difasie := nvl(v_val_garantia_ant,0) -
                           nvl(v_sal_linea_ant,0) -
                           nvl(v_vlmoncu,0);

             --
             v_ttlcrmon := v_ttlcrmon + v_difasie;
             --
             /*update pr_garantias
                      set pr_garantias.sal_linea = pr_garantias.sal_linea + nvl(ww_difasie,0)
                    where pr_garantias.nro_garantia = ww_antgara;*/

          end if;
          --
          if nvl(v_ant_moneda,'  ') <> v_cod_mon_gar  then
             if nvl(v_ttlcrmon,0) <> 0   then
                lp_gen_movimiento(950,951,v_ant_moneda,v_ttlcrmon);
             end if;
             v_ant_moneda := v_cod_mon_gar;
             v_ttlcrmon   := 0;
          end if;
          --
          v_ant_garantia := v_nro_garantia;
          v_val_garantia_ant:= v_val_garantia;
          v_sal_linea_ant:= v_sal_linea;
          v_vlmoncu := 0;
       end if;
       --
       if v_val_garantia - v_vlmoncu > 0 then
          v_totdeuda := lf_conv_moneda_garantia(v_cod_moneda,
                          v_cod_mon_gar, v_sal_capital + v_dev_no_cobrado);
          if v_val_garantia - v_vlmoncu > v_totdeuda then
             update pr_cta_garantias
                set mto_apl_computable = v_totdeuda
              where pr_cta_garantias.nro_garantia = v_nro_garantia
                and pr_cta_garantias.nro_cuenta = v_nro_cuenta;
             v_vlmoncu := v_vlmoncu +  v_totdeuda;
          else
             update pr_cta_garantias
                set mto_apl_computable = v_val_garantia - v_vlmoncu
              where pr_cta_garantias.nro_garantia = v_nro_garantia
                and pr_cta_garantias.nro_cuenta = v_nro_cuenta;
             v_vlmoncu := v_vlmoncu + (v_val_garantia - v_vlmoncu);
          end if;
       else
          update pr_cta_garantias
             set mto_apl_computable = 0
           where pr_cta_garantias.nro_garantia = v_nro_garantia
            and pr_cta_garantias.nro_cuenta = v_nro_cuenta;
       end if;
   end loop; -- de caja --
   --
   if  nvl(v_vlmoncu,0) <> 0 then
       v_difasie := nvl(v_val_garantia_ant,0) -
                     nvl(v_sal_linea_ant,0) -
                     nvl(v_vlmoncu,0);
     --
     v_ttlcrmon := v_ttlcrmon + v_difasie;
     /*update pr_garantias
        set pr_garantias.sal_linea = pr_garantias.sal_linea + v_difasie
      where pr_garantias.nro_garantia = v_ant_garantia;*/
     --
   end if;
   if nvl(v_ttlcrmon,0) <> 0 then
      lp_gen_movimiento(950,951,v_ant_moneda,v_ttlcrmon);
   end if;
   --
   if garantia%isopen then
     close garantia;
   end if;
exception
    when no_data_found then
        raise_application_error(-20000,'No existe datos en el archivo verifique');
end;
--Proceso Principal
BEGIN
  v_moneloc      := PAG_GEN.FU_OBT_MON_LOCAL ;
  v_fcdehoy      := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
  v_nro_secuencia:= 0;
  v_cod_usuario  := user;
  v_hora         := to_char(sysdate,'HH24:MI:SS');

  begin
    select cod_oficina
      into v_cod_oficina
      from ba_usuarios
     where cod_usuario = v_cod_usuario;
  exception
    when no_data_found then
      raise_application_error(-20000,'Al Buscar oficina del usuario');
  end;
  lp_actualizar; 
  lp_pro_gar_real;
  --lp_ina_gar_reales;
  --lp_act_capital;
  
  /*
  || SDRES12BCP-1: Clasificación-Previsión-Refinanciaciones y/o Reestructuraciones
  || 314 PRP_CAL_ATRASOS 
  || 329 PRP_ACT_GARANTIA
  || 338 PRP_PRO_PREVISIONES
  */
  
  prp_act_gar_hip_res12;
  
END;
/