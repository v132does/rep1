CREATE OR REPLACE PROCEDURE IT.PRG_GEN_CTA_AGUINALDOS (p_fecha            in date,
                                                    --Parametros de la Empresa
                                                      p_cod_empresa      in number,
                                                    --Parametros del Cliente
                                                      p_cod_oficina      in number,
                                                      p_cod_usu_oficial  in varchar2,
                                                      p_cod_departamento in number,
                                                      p_tip_extracto     in varchar2,
                                                      p_cod_moneda       in varchar2)
 IS
  v_cod_persona        ba_personas.cod_persona%type;
  v_codigo             ba_personas.cod_persona%type;
  v_nro_cuenta         ge_cuentas.nro_cuenta%type;
  v_nro_sec_movimiento ge_movimientos.nro_secuencia%type    :=0;
  v_cod_ofi_origen     ge_movimientos.cod_ofi_origen%type;
  v_cod_seg_cliente    ge_clientes.cod_seg_cliente%type     := FUG_OBT_PARENTES(p_cod_empresa,'COD_SEG_CLIENTE');   -- segmento : Particulares Nomina 
  v_cod_modulo         cc_cta_corrientes.cod_modulo%type    := 3;
  v_cod_modalidad      cc_cta_corrientes.cod_modalidad%type := 31;
  v_estado             cc_cta_corrientes.estado%type        := 'A'; -- Estado de la Cuenta Corriente
  v_denominacion       cc_cta_corrientes.denominacion%type;
  v_observacion        varchar2(50):= 'PLAN SUELDO';
  v_cli_existe         varchar2(1) := 'N';
  v_tas_existe         varchar2(1) := 'N';
  v_ret_existe         varchar2(1) := 'N';
  v_tra_existe         varchar2(1) := 'N';
  v_cod_ofi_ahorro     number(5) := null;
  v_cod_tip_documento  ba_tip_documentos.cod_tip_documento%type;
  v_nro_documento      ba_personas.nro_documento%type;
  v_lugar              varchar2(50);
  v_cod_pro_bancard 	 VARCHAR2(10) := fug_obt_pardinamico( 'COD_PRO_BANCARD', null, null, null, null );
  v_cod_tasa           ge_tasas.cod_tasa%type := FUG_OBT_PARENTES(p_cod_empresa,'COD_TAS_CTA_AGUINALDO');
  -- Obtiene los clientes temporales.
  cursor tem is
    select cod_persona, nro_cta_ahorro, tip_documento, nro_cedula,
           cod_empresa, pri_nombre, seg_nombre, pri_apellido, seg_apellido,
           fec_nacimiento, sexo, est_civil, direccion, ciudad, telefono
      from GE_PAG_AGU_EMP_TMP
     where cod_empresa = p_cod_empresa
       and error is null;
  -- Obtiene los Parametros de las Tasa y Tarifas.
  cursor cta_tas is
      select cod_tasa, valor
        from ge_seg_par_cta_tas
       where cod_modulo      = v_cod_modulo
         and cod_modalidad   = v_cod_modalidad
         and cod_seg_cliente = v_cod_seg_cliente
         and cod_moneda      = p_cod_moneda;
  -- Obtiene parametros de Retenciones.
  cursor cta_ret is
      select cod_retencion, can_dia_retencion
        from ge_seg_par_cta_ret
       where cod_modulo      = v_cod_modulo
         and cod_modalidad   = v_cod_modalidad
         and cod_seg_cliente = v_cod_seg_cliente
         and cod_moneda      = p_cod_moneda;
  -- Obtiene parametros de Transacciones Prohibidas.
  cursor cta_tra is
      select cod_transaccion, cod_mod_transaccion, cod_mad_transaccion
        from ge_seg_par_cta_tra
       where cod_modulo      = v_cod_modulo
         and cod_modalidad   = v_cod_modalidad
         and cod_seg_cliente = v_cod_seg_cliente
         and cod_moneda      = p_cod_moneda;
  --- Funcion que retorna el codigo de persona desde el documento
  function lf_obt_cod_persona(p_cod_persona  varchar2)
                              return varchar2 is
   v_codigo ba_personas.cod_persona%type;                              
  begin
    -- Busca la persona
    begin
      select cod_persona
        into v_codigo
        from ba_personas
       where cod_persona = p_cod_persona;
    exception
      when no_data_found then
        raise_application_error(-20001,'No existe la persona '||p_cod_persona);
      when others then
        raise_application_error(-20001,'Error al buscar la persona '||p_cod_persona||' '||sqlerrm);
    end;  
    Return v_codigo;
   End; 
  -- Recupera el nombre que puede ser almacenado dependiendo de la cantidad de caracteres permitidos
  function lf_obt_nombre(p_pri_nombre   varchar2,
                         p_seg_nombre   varchar2,
                         p_pri_apellido varchar2,
                         p_seg_apellido varchar2,
                         p_tamano       number) return varchar2 is
   v_nombre varchar2(120);
  begin
    if length(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano then
      if length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano then
        if length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano then
          v_nombre := p_pri_nombre||' '||p_pri_apellido;
        else
          v_nombre := trim(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
        end if;
      else
        v_nombre := trim(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
      end if;
    else
      v_nombre := trim(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
    end if;
    return v_nombre;
  end;
  --
  function lf_obt_cta_av(p_persona   varchar2,
                         p_documento varchar2,
                         p_cod_moneda varchar2 ) return varchar2 is
    v_cuenta ge_cta_clientes.nro_cuenta%type;
  begin
    begin
      select c.nro_cuenta
        into v_cuenta
        from ge_cta_clientes c
       where c.cod_persona = p_persona
         and c.relacion = 'P'
         and exists(select *  from ah_cta_vistas cc
                      where c.nro_cuenta = cc.nro_cuenta
                        and cc.cod_moneda = p_cod_moneda
                        and cc.cod_ente   = p_cod_empresa
                        and cc.estado not in ('C','P')
                        and cc.cod_sub_modalidad = 6);
    exception
      when no_data_found then
        v_cuenta := null;
      when others then
        raise_application_error(-20005,'Error al buscar la Cuenta AV. Documento Nro='||p_documento||' '||sqlerrm);
    end;
    return v_cuenta;
  end;
  --
  procedure lp_obt_tar_debito(p_cod_persona varchar2,
                              p_documento   varchar2,
                              p_nro_cuenta  varchar2)
  is
   v_existe number := 0;   
   -- Asigna a todas las tarjetas activas
   cursor c_tar_debitos is
   select distinct a.nro_cuenta, a.adherente
     from ah_tar_debitos a
     where a.cod_persona = p_cod_persona
       and a.nro_cuenta  like '%'||p_nro_cuenta
       and a.fec_vencimiento >= pag_cal.FU_OBT_FEC_ACTUAL(3);
   -- A pedido de Clara Garcia, el 16/dic/2010, por rabf
   -- Si no hay tarjetas activas, toma las vencidas
   cursor c_tar_vencidas is
   select distinct a.nro_cuenta, a.adherente
     from ah_tar_debitos a
     where a.cod_persona = p_cod_persona
       and a.nro_cuenta  like '%'||p_nro_cuenta;
  begin
    for i in c_tar_debitos loop
      if nvl(v_existe,0) = 0 then
         v_existe := 1;
      end if;
      begin
        v_lugar := '29-ah_tar_deb_cuentas';
        if i.nro_cuenta != v_nro_cuenta then
           insert into ah_tar_deb_cuentas
             (nro_cuenta, cod_persona, nro_cta_relacionada, cod_ent_procesadora, adherente)
           values
             (i.nro_cuenta, v_cod_persona, v_nro_cuenta, v_cod_pro_bancard, i.adherente);
        end if;
      exception
        when others then
          raise_application_error(-20038,'Error al insertar en AH_TAR_DEBITOS documento ='||p_documento||' '||sqlerrm);
      end;
    end loop;
    ---
    if nvl(v_existe,0) = 0 then
       for i in c_tar_vencidas loop
         if nvl(v_existe,0) = 0 then
            v_existe := 1;
         end if;
         begin
           v_lugar := '30-ah_tar_deb_cuentas';
           if i.nro_cuenta != v_nro_cuenta then  
              insert into ah_tar_deb_cuentas
                (nro_cuenta, cod_persona, nro_cta_relacionada, cod_ent_procesadora, adherente)
              values
                (i.nro_cuenta, v_cod_persona, v_nro_cuenta, v_cod_pro_bancard, i.adherente);
           end if;
         exception
           when others then
             raise_application_error(-20038,'Error al insertar en AH_TAR_DEBITOS documento ='||p_documento||' '||sqlerrm);
         end;
       end loop;
    end if;
    ---
    if nvl(v_existe,0) = 0 then
         begin
              insert into ah_tar_deb_cuentas
                (nro_cuenta, cod_persona, nro_cta_relacionada, cod_ent_procesadora, adherente)
              values
                (v_nro_cuenta, v_cod_persona, v_nro_cuenta, v_cod_pro_bancard,'00');
         exception
           when others then
             raise_application_error(-20038,'Error al insertar en AH_TAR_DEBITOS documento ='||p_documento||' '||sqlerrm);
         end;

    end if;
  end;
-- INICIO PROCESO PRINCIPAL --
BEGIN
  BEGIN pre_ini_aplicacion; PAE_CNF.G_COD_MODULO:=1;END;
  for t in tem loop
    -- Inicializa variables
    v_codigo     := null;
    v_cli_existe := 'N';
    v_ret_existe := 'N';
    v_tra_existe := 'N';
    v_tas_existe := 'N';
    v_cod_ofi_ahorro := null;

    -- Obtiene el tipo de documento
    begin
      select cod_tip_documento
        into v_cod_tip_documento
        from ba_tip_documentos
       where abreviatura = t.tip_documento;
         --and cod_tip_documento in (1,2,3,5); -- CI, PAS, CRP, CRC
    exception 
      when no_data_found then
        raise_application_error(-20010,'Tipo de documento no registrado. Documento Nro='||t.nro_cedula||' '||sqlerrm);
    end;

    v_lugar := '1-Datos Persona';
   /*
   ||  Ya existe como persona entonces solo se da de alta la cuenta y como cliente
   */
      v_cod_persona := lf_obt_cod_persona(t.cod_persona);   
      begin
        select distinct 'S'
          into v_cli_existe
          from ge_clientes
         where cod_persona = v_cod_persona;
      exception
        when no_data_found then
          v_cli_existe := 'N';
        when others then
          raise_application_error(-20004,'Error al buscar el cliente. Documento Nro='||t.nro_cedula||' '||sqlerrm);
      end;
      -- **CLIENTES** --
      if v_cli_existe = 'N' then
        begin
          insert into ge_clientes
            (cod_persona, cod_oficina, cod_usu_oficial, cod_departamento, tip_extracto, cod_seg_cliente,residente,cod_sec_contable,cod_tip_deudor)
          values
            (v_cod_persona, p_cod_oficina, p_cod_usu_oficial, p_cod_departamento, 'N', v_cod_seg_cliente,'S','N',2);
        exception
          when others then
            raise_application_error(-20021,'Error al insertar datos en GE_CLIENTES. Documento Nro='||t.nro_cedula||' '||sqlerrm);
        end;
      else
        begin
          v_lugar := '15-Update GE_CLIENTES';
          update ge_clientes
             set cod_seg_cliente = v_cod_seg_cliente
           where cod_persona = v_cod_persona;
        exception
          when others then
            raise_application_error(-20022,'Error al modificar datos en GE_CLIENTES. Documento Nro='||t.nro_cedula||' '||sqlerrm);
        end;
      end if;      
    -- **CUENTA AV** --
    if t.nro_cta_ahorro is not null then
      v_nro_cuenta := t.nro_cta_ahorro;
    else
      v_nro_cuenta := lf_obt_cta_av(v_cod_persona, t.nro_cedula, p_cod_moneda);
    end if;
    if v_nro_cuenta is null then
      v_lugar := '16-CTAAV';
      v_nro_cuenta   := fug_obt_sig_nro_cuenta(v_cod_modulo,v_cod_modalidad,p_cod_oficina,p_cod_moneda,v_cod_persona);
      v_denominacion := lf_obt_nombre(t.pri_nombre,t.seg_nombre,t.pri_apellido,t.seg_apellido,65);
      -- ah_cta_vistas
      begin
        v_lugar := '18-Insert AH_CTA_VISTAS';
        insert into ah_cta_vistas
          (cod_modulo, cod_modalidad, cod_oficina,
           nro_cuenta, dig_verificador, cod_moneda,
           denominacion, fre_extracto,
           fec_apertura, ret_personalizada, tas_personalizada,
           tip_capitalizacion,  cod_tasa, aut_pendiente,
           tra_prohibida, cta_combinada, estado, est_batch,    
           cod_sub_modalidad, cod_ente, reg_firma)
        values
          (v_cod_modulo, v_cod_modalidad, nvl(v_cod_ofi_ahorro,p_cod_oficina),
          v_nro_cuenta, 0, p_cod_moneda,
          v_denominacion,'M',
          p_fecha, 'N', 'N',
          1,v_cod_tasa, 'N',
          'N','N', 'A','A',
           6,p_cod_empresa, 'ALTA MASIVA CUENTA AGUINALDO');
      exception
        when others then
          raise_application_error(-20030,'Error al insertar datos en AH_CTA_VISTAS. Documento Nro='||t.nro_cedula||' '||sqlerrm);
      end;
      -- ge_cta_clientes
      begin
        v_lugar := '19-Insert GE_CTA_CLIENTES';
        insert into ge_cta_clientes
          (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo, cod_modalidad, relacion)
        values
          (v_cod_persona, v_nro_cuenta, 0, nvl(v_cod_ofi_ahorro,p_cod_oficina), v_cod_modulo, v_cod_modalidad, 'P');
      exception
        when others then
          raise_application_error(-20050,'Error al insertar datos en GE_CTA_CLIENTES. Documento Nro='||t.nro_cedula||sqlerrm);
      end;
      begin
          v_lugar := '21-Oficina';
        select cod_oficina
          into v_cod_ofi_origen
          from ba_usuarios
         where cod_usuario = user;
      exception
        when others then
          raise_application_error(-20039,'Error al buscar la Oficina Origen. Documento Nro='||t.nro_cedula||' '||sqlerrm);
      end;
      -- ge_movimientos
      v_nro_sec_movimiento := v_nro_sec_movimiento + 1;
      begin
        v_lugar := '22-Insert GE_MOVIMIENTOS';
        insert into ge_movimientos
          (fecha, hora, cod_usuario, nro_secuencia, fec_valor, nro_cuenta, cod_moneda, cod_oficina, est_cuenta, estado, cod_ofi_origen, concepto, cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_transaccion, cod_modulo, cod_modalidad)
        values
          (p_fecha, to_char(sysdate,'hh24:mi:ss'), user, v_nro_sec_movimiento, p_fecha, v_nro_cuenta, p_cod_moneda, nvl(v_cod_ofi_ahorro,p_cod_oficina), 'A', 'N',v_cod_ofi_origen, 'Cambio de Estado', 401, v_cod_modulo, v_cod_modalidad, 401, v_cod_modulo, v_cod_modalidad);
      exception
        when others then
          raise_application_error(-20039,'Error al insertar en GE_MOVIMIENTOS. Documento Nro='||t.nro_cedula||' '||sqlerrm);
      end;
      -- ge_ret_cuentas
      for ret in cta_ret loop
        v_lugar := '23-GE_RET_CUENTAS';
        v_ret_existe := 'S';
        begin
            v_lugar := '24';
          insert into ge_ret_cuentas
            (cod_retencion, nro_cuenta, can_dia_retencion,  observaciones)
          values
            (ret.cod_retencion, v_nro_cuenta, ret.can_dia_retencion, v_observacion);
        exception
          when others then
            raise_application_error(-20031,'Error al insertar datos en GE_RET_CUENTAS. Documento Nro='||t.nro_cedula||' '||sqlerrm);
        end;
      end loop;
      -- ge_tra_prohibidas
      for tra in cta_tra loop
        v_tra_existe := 'S';
        begin
          v_lugar := '25-GE_TRA_PROHIBIDAS';
          insert into ge_tra_prohibidas
            (cod_transaccion, cod_modulo, cod_modalidad, nro_cuenta, observaciones)
          values
            (tra.cod_transaccion, tra.cod_mod_transaccion, tra.cod_mad_transaccion, v_nro_cuenta, v_observacion);
        exception
          when others then
            raise_application_error(-20032,'Error al insertar datos en GE_TRA_PROHIBIDAS. Documento Nro='||t.nro_cedula||' '||sqlerrm);
        end;
      end loop;
      -- ge_tas_fechas
      for tas in cta_tas loop
          v_lugar := '26-GE_TAS_FECHAS';
        v_tas_existe := 'S';
        begin
          insert into ge_tas_fechas
            (cod_tasa, fec_vigencia, nro_cuenta, val_tasa, aplicar,  observaciones)
          values
            (tas.cod_tasa, p_fecha, v_nro_cuenta, tas.valor, 'ST', v_observacion);
        exception
          when others then
            raise_application_error(-20033,'Error al insertar datos en GE_TAS_FECHAS. Documento Nro='||t.nro_cedula||' '||sqlerrm);
        end;
      end loop;
      -- actualiza la cuenta corriente --
      begin
        v_lugar := '27-AH_CTA_VISTAS';
        update ah_cta_vistas
           set ret_personalizada = v_ret_existe,
               tas_personalizada = v_tas_existe,
               tra_prohibida     = v_tra_existe
         where nro_cuenta = v_nro_cuenta;
      exception
        when others then
          raise_application_error(-20037,'Error al modificar AH_CTA_VISTAS. Documento Nro='||t.nro_cedula||' '||sqlerrm);
      end;
      -- verificacion de cuenta
      begin
        update ah_cta_vistas
           set estado = v_estado
         where nro_cuenta = v_nro_cuenta;
        update ge_cuentas
           set est_verificacion = 'V'
         where nro_cuenta = v_nro_cuenta;
      exception
        when others then
          raise_application_error(-20050,'Error al verificar la cuenta. Documento Nro='||t.nro_cedula||sqlerrm);
      end;
    end if;
    /*
    || Genera Tarjeta de Debito si no tiene.
    || Si tiene, agrega la relacion con la cuenta principal de cobro de salario.
    */
    lp_obt_tar_debito(v_cod_persona,t.nro_cedula,t.nro_cta_ahorro);
  end loop;
  --** Elimina los registros de la tabla temporal **--
  begin
    delete GE_PAG_AGU_EMP_TMP
     where cod_empresa = p_cod_empresa;
  exception
    when others then
      raise_application_error(-20060,'Error al eliminar registros de GE_PAG_AGU_EMP_TMP '||sqlerrm);
  end;
  --** **--
exception
    when others then
      raise_application_error(-20019,v_nro_documento||'-'||v_lugar||'-'||sqlerrm);
END;
/

