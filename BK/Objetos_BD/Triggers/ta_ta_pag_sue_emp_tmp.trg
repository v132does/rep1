CREATE OR REPLACE TRIGGER IT.TA_TA_PAG_SUE_EMP_TMP
AFTER  INSERT ON TA_PAG_SUE_EMP_TMP
FOR EACH ROW

DECLARE

  rg_par_cuentas       ge_seg_par_cuentas%rowtype;
  v_cod_persona        ba_personas.cod_persona%type;
  v_codigo             ba_personas.cod_persona%type;
  v_est_civil          ba_per_fisicas.est_civil%type;
  v_area               ba_telefonos.area%type;
  v_tipo               ba_telefonos.tipo%type;
  v_num_telefono       ba_telefonos.telefono%type;
  v_cod_ciudad         ba_ciudades.cod_ciudad%type;
  v_nro_cuenta         ge_cuentas.nro_cuenta%type;
  v_nro_sec_movimiento ge_movimientos.nro_secuencia%type    :=0;
  v_cod_ofi_origen     ge_movimientos.cod_ofi_origen%type;
  v_emp_nro_cuenta     cc_cta_corrientes.nro_cuenta%type;
  v_cod_seg_cliente    ge_clientes.cod_seg_cliente%type     := 26;   -- segmento : Particulares Nomina (BBVA)
  v_cod_modulo         cc_cta_corrientes.cod_modulo%type    := 4;
  v_cod_modalidad      cc_cta_corrientes.cod_modalidad%type := 41;
  v_cod_cargo          cr_tip_cargos.cod_tip_cargo%type     := 43;
  v_estado             cc_cta_corrientes.estado%type        := 'A'; -- Estado de la Cuenta Corriente
  v_cod_moneda         cc_cta_corrientes.cod_moneda%type;
  v_denominacion       cc_cta_corrientes.denominacion%type;
  v_nom_chequera       cc_cta_corrientes.nom_chequera%type;
  v_nro_secuencia      cc_lin_sobregiros.nro_secuencia%type;
  v_nro_sec_padre      cc_lin_sobregiros.nro_secuencia%type;
  v_nro_sec_aguinaldo  cc_lin_sobregiros.nro_secuencia%type;
  v_nro_sec_agu_padre  cc_lin_sobregiros.nro_secuencia%type;
  v_fec_ven_sobregiro  cc_lin_sobregiros.fec_vencimiento%type;
  v_embozado           ah_tar_debitos.embozado%type;
  v_fec_vencimiento    ah_tar_debitos.fec_vencimiento%type;
  v_direccion          ba_direcciones.direccion%type;
  v_obs_direccion      ba_direcciones.observacion%type;
  v_cod_concepto       cr_con_ing_egr.cod_concepto%type;
  v_anio               varchar2(10);
  v_observacion        varchar2(50):= 'PLAN SUELDO';
  v_cli_existe         varchar2(1) := 'N';
  v_tas_existe         varchar2(1) := 'N';
  v_ret_existe         varchar2(1) := 'N';
  v_tra_existe         varchar2(1) := 'N';
  v_cod_ofi_ahorro     number(5) := null;
  v_emp_cod_persona    ba_personas.cod_persona%type;
  v_cod_dir_laboral    ba_direcciones.cod_direccion%type;
  v_cod_tel_laboral    ba_telefonos.cod_telefono%type;
  v_cod_tip_documento  ba_tip_documentos.cod_tip_documento%type;
  v_nro_documento      ba_personas.nro_documento%type;
  v_cod_oficina        ba_oficinas.cod_oficina%type := fug_obt_pardinamico( 'COD_OFI_VTA_TARJETAS' );
  v_cod_usu_oficial    ba_usuarios.cod_usuario%type;
  v_cod_ofi_oficial    ba_oficinas.cod_oficina%type;
  v_lugar              varchar2(50);
  v_fec_actual         cr_act_esperadas.fecha%type := pag_cal.FU_OBT_FEC_ACTUAL(3);
  -- Obtiene los clientes temporales.
  cursor cta_tas is
      select cod_tasa, valor
        from ge_seg_par_cta_tas
       where cod_modulo      = v_cod_modulo
         and cod_modalidad   = v_cod_modalidad
         and cod_seg_cliente = v_cod_seg_cliente
         and cod_moneda      = v_cod_moneda;
  -- Obtiene par·metros de Retenciones.
  cursor cta_ret is
      select cod_retencion, can_dia_retencion
        from ge_seg_par_cta_ret
       where cod_modulo      = v_cod_modulo
         and cod_modalidad   = v_cod_modalidad
         and cod_seg_cliente = v_cod_seg_cliente
         and cod_moneda      = v_cod_moneda;
  -- Obtiene par·metros de Transacciones Prohibidas.
  cursor cta_tra is
      select cod_transaccion, cod_mod_transaccion, cod_mad_transaccion
        from ge_seg_par_cta_tra
       where cod_modulo      = v_cod_modulo
         and cod_modalidad   = v_cod_modalidad
         and cod_seg_cliente = v_cod_seg_cliente
         and cod_moneda      = v_cod_moneda;
  -- Busca si ya existe la persona o cliente
function lf_obt_personas(p_nro_documento  varchar2,
                           p_cod_tip_documento  varchar2,
                           p_pri_nombre     varchar2,
                           p_pri_apellido   varchar2,
                           p_seg_nombre     varchar2,
                           p_seg_apellido   varchar2,
                           p_sexo           varchar2,
                           p_fec_nacimiento date) return varchar2 is
    v_per_existe    varchar2(1):= 'N';
    v_nro_documento ba_personas.nro_documento%type;

BEGIN

   -- Busca la personas en GestiÛn
    begin
      select cod_persona
        into v_codigo
        from ba_personas
       where nro_documento = p_nro_documento
         and cod_tip_documento = p_cod_tip_documento;
         v_per_existe := 'S';
    exception
      when no_data_found then
        v_per_existe := 'N';
      when others then
        raise_application_error(-20001,'Error al buscar la persona. Docuemento Nro='||p_nro_documento||' '||sqlerrm);
    end;
    if v_per_existe = 'S' then
      -- Si el documento existe busca si el primer nombre y primer apellido son iguales con el ingresado.
      begin
        select 'S'
          into v_per_existe
          from ba_per_fisicas
         where upper(ltrim(rtrim(pri_nombre)))  = upper(ltrim(rtrim(p_pri_nombre)))
           and upper(ltrim(rtrim(pri_apellido))) = upper(ltrim(rtrim(p_pri_apellido)))
           and cod_persona = v_codigo;
      exception
        when no_data_found then
          raise_application_error(-20002,'Existe una persona con el Documento Nro='||p_nro_documento);
        when others then
          raise_application_error(-20003,'Error al buscar la persona. Documento Nro='||p_nro_documento||' '||sqlerrm);
      end;
      begin
        select distinct 'S'
          into v_cli_existe
          from ge_clientes
         where cod_persona = v_codigo;
      exception
        when no_data_found then
          v_cli_existe := 'N';
        when others then
          raise_application_error(-20004,'Error al buscar el cliente. Documento Nro='||p_nro_documento||' '||sqlerrm);
      end;
    else
      begin
        select p.nro_documento
          into v_nro_documento
          from ba_personas p,
               ba_per_fisicas pf
         where p.cod_persona = pf.cod_persona
           and upper(ltrim(rtrim(pri_nombre)))  = upper(ltrim(rtrim(p_pri_nombre)))
           and upper(ltrim(rtrim(pri_apellido))) = upper(ltrim(rtrim(p_pri_apellido)))
           and upper(ltrim(rtrim(nvl(seg_nombre,'XX'))))  = upper(ltrim(rtrim(nvl(p_seg_nombre,'XX'))))
           and upper(ltrim(rtrim(nvl(seg_apellido,'XX')))) = upper(ltrim(rtrim(nvl(p_seg_apellido,'XX'))))
           and nvl(fec_nacimiento,sysdate) = nvl(p_fec_nacimiento,sysdate)
           and cod_sexo = nvl(p_sexo,'X')
           and rownum = 1;
       exception
         when no_data_found then
           v_per_existe := 'N';
         when others then
           raise_application_error(-20005,'Error al buscar Personas Parecidas. Documento Nro='||p_nro_documento||' '||sqlerrm);
       end;
       if v_nro_documento is not null then
         raise_application_error(-20006,'Existen personas parecidas para '||p_pri_nombre||' '||p_pri_apellido||' verifique en el sistema el Documento Nro='||v_nro_documento||' '||sqlerrm);
       end if;
    end if;
    return v_per_existe;
  end;
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
  function lf_obt_cta_corriente(p_persona   varchar2,
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
         and exists(select *  from cc_cta_corrientes cc
                      where c.nro_cuenta = cc.nro_cuenta
                        and cc.cod_moneda = p_cod_moneda
                        and cc.estado not in ('C'));
    exception
      when no_data_found then
        v_cuenta := null;
      when others then
        raise_application_error(-20005,'Error al buscar la Cuenta Corriente. Documento Nro='||p_documento||' '||sqlerrm);
    end;
    return v_cuenta;
  end;
  --
  function lf_obt_lin_sobregiro(p_nro_cuenta varchar2,
                                p_documento  varchar2,
                                p_tipo       varchar2)
    return varchar2 is
    v_existe varchar2(1):= 'N';
  begin
    begin
      select distinct 'S'
        into v_existe
        from cc_lin_sobregiros
       where nro_cuenta = p_nro_cuenta
         and tipo       = p_tipo;
    exception
      when no_data_found then
        v_existe := 'N';
      when others then
        raise_application_error(-20005,'Error al buscar LÌneas de Sobregiro. Documento Nro='||p_documento||' '||sqlerrm);
    end;
    return v_existe;
  end;
  --
  function lf_obt_tar_debito(p_cod_persona varchar2,
                             p_documento  varchar2)
    return varchar2 is
    v_existe varchar2(1):= 'N';
  begin
    begin
      select distinct 'S'
        into v_existe
        from ah_tar_debitos
        where cod_persona = p_cod_persona
          and cod_est_solicitud not in (1, 2, 16); -- Rechazada, Ingresada, Anulada
    exception
      when no_data_found then
        v_existe := 'N';
      when others then
        raise_application_error(-20005,'Error al buscar Tarjeta de DÈbito. Documento Nro='||p_documento||' '||sqlerrm);
    end;
    return v_existe;
  end;
  --
  procedure lp_obt_dat_cuentas(p_nro_cuenta    varchar2) is
  begin
    -- Obtiene datos de la Cuenta Corriente de la Empresa
    begin
      select cod_moneda
        into v_cod_moneda
        from cc_cta_corrientes
       where nro_cuenta = p_nro_cuenta;
    exception
      when others then
        raise_application_error(-20008,'Error al buscar datos CC_CTA_CORRIENTES. Cta: '||p_nro_cuenta||'-'||sqlerrm);
    end;
    -- Obtiene par·metros de la Cuenta.
    begin
      select tip_extracto, cod_ente,
             min_pactado, tip_capitalizacion,
             cod_tasa, plazo, gen_tar_debito
        into rg_par_cuentas.tip_extracto, rg_par_cuentas.cod_ente,
             rg_par_cuentas.min_pactado, rg_par_cuentas.tip_capitalizacion,
             rg_par_cuentas.cod_tasa, rg_par_cuentas.plazo, rg_par_cuentas.gen_tar_debito
        from ge_seg_par_cuentas
       where cod_modulo      = v_cod_modulo
         and cod_modalidad   = v_cod_modalidad
         and cod_seg_cliente = v_cod_seg_cliente
         and cod_moneda      = v_cod_moneda;
    exception
      when others then
        raise_application_error(-20009,'Error al buscar par·metros del Plan Sueldo. '||sqlerrm);
    end;
  end;
-- INICIO PROCESO PRINCIPAL --
BEGIN
    -- Inicializa variables
    v_codigo     := null;
    v_cli_existe := 'N';
    v_ret_existe := 'N';
    v_tra_existe := 'N';
    v_tas_existe := 'N';
    v_cod_ofi_ahorro := null;

   If :new.cod_empresa is not null then
     Begin
       select cod_persona
         into v_emp_cod_persona
         from ge_entes
        where cod_ente = :NEW.cod_empresa;
     Exception
        when no_data_found then
          raise_application_error(-20010,'Error al traer codigo de persona del ente. Codigo de Ente='||:NEW.cod_empresa||' '||sqlerrm);
     End;
   End if;
    -- Obtiene el tipo de documento
   begin
      select cod_tip_documento
        into v_cod_tip_documento
        from ba_tip_documentos
       where abreviatura = :NEW.tip_documento
         and abreviatura in('CI','PAS','DNI','CRP');
    exception
      when no_data_found then
        raise_application_error(-20010,'Tipo de documento no registrado. Documento Nro='||:NEW.nro_cedula||' '||sqlerrm);
      when others then
        v_cod_tip_documento := 1;
        --raise_application_error(-20010,'Error al buscar tipo de documento. Documento Nro='||:NEW.nro_cedula||' '||sqlerrm);
    end;
    v_lugar := '1-Datos Persona';
    -- **DATOS PERSONAS** --
    if lf_obt_personas(:NEW.nro_cedula,v_cod_tip_documento,:NEW.pri_nombre,:NEW.pri_apellido,:NEW.seg_nombre,:NEW.seg_apellido,:NEW.sexo,:NEW.fec_nacimiento) = 'N' then
      v_nro_documento := :NEW.nro_cedula;
      -- ba_personas
      select s_cod_persona.nextval into v_cod_persona from dual;
      begin
        insert into ba_personas
          (cod_persona, nom_completo,tipo, cod_tip_documento, nro_documento, cod_pais, cod_actividad, est_verificacion, obs_verificacion, fec_vto_documento)
        values
          (v_cod_persona, :NEW.pri_nombre||' '||:NEW.seg_nombre||' '||:NEW.pri_apellido||' '||:NEW.seg_apellido,'F',v_cod_tip_documento,:NEW.nro_cedula, 1,701,'V','PLAN SUELDOS', :NEW.fec_vto_documento);
      exception
        when others then
          raise_application_error(-20010,'Error al insertar datos en BA_PERSONAS. Documento Nro='||:NEW.nro_cedula||' '||'Cod_persona : '||v_cod_persona||' '||sqlerrm);
      end;
    v_lugar := '2-Obtengo estado Civil';
      if :NEW.est_civil is not null then
        -- ba_per_fisicas
        begin
          select val_minimo
            into v_est_civil
            from ba_cod_referencias
           where dominio = 'COD_EST_CIVIL'
             and upper(substr(significado,1,3)) like '%'||ltrim(rtrim(upper(substr(:NEW.est_civil,1,3))))||'%';
        exception
          when no_data_found then
            raise_application_error(-20011,'No existe estado civil definido. Documento Nro='||:NEW.nro_cedula);
          when others then
            --raise_application_error(-20012,'Error al buscar el Estado Civil Documento. Nro='||:NEW.nro_cedula||' '||sqlerrm);
            v_Est_civil := 'S';
        end;
      else
        v_est_civil := 'S';
      end if;
      begin
          v_lugar := '3-Insert BA_PER_FISICAS';
        insert into ba_per_fisicas
          (cod_persona, pri_nombre, pri_apellido, est_civil, cod_sexo, cod_pai_nacionalidad,seg_nombre, seg_apellido, fec_nacimiento)
        values
          (v_cod_persona, :NEW.pri_nombre, :NEW.pri_apellido, v_est_civil, :NEW.sexo, 1,:NEW.seg_nombre, :NEW.seg_apellido, :NEW.fec_nacimiento);
      exception
        when others then
          raise_application_error(-20013,'Error al insertar datos en BA_PER_FISICAS. Documento Nro='||:NEW.nro_cedula||' '||sqlerrm);
      end;
      -- ba_direcciones
      if :NEW.direccion is null then
         raise_application_error(-20013,'La persona de Documento Nro='||:NEW.nro_cedula||' No tiene direccion.'||sqlerrm);
      End if;
      if :NEW.direccion is not null then
        if :NEW.ciudad is not null then
          -- Busca primero por nombre exacto
          begin
            select cod_ciudad
              into v_cod_ciudad
              from ba_ciudades
             where translate(upper(descripcion),'¡…Õ”⁄','AEIOU') = ltrim(rtrim(translate(:NEW.ciudad,'¡…Õ”⁄','AEIOU')));
          exception
            when others then
              null;
          end;
          -- Buscar por nombre similar
          if v_cod_ciudad is null then
            begin
              select cod_ciudad
                into v_cod_ciudad
                from ba_ciudades
               where translate(upper(descripcion),'¡…Õ”⁄','AEIOU') like
                     '%'||ltrim(rtrim(translate(:NEW.ciudad,'¡…Õ”⁄','AEIOU')))||'%';
            exception
              when others then
                raise_application_error(-20014,'Error al buscar la ciudad '||:NEW.ciudad||'. Documento Nro='||:NEW.nro_cedula||' '||sqlerrm);
            end;
          end if;
        else
          v_cod_ciudad := null;
        end if;
        begin
          v_lugar := '4-Direccion';
          v_direccion     := substr(:NEW.direccion,1,80);
          v_obs_direccion := substr(:NEW.direccion,81);
          insert into ba_direcciones
            (cod_persona, cod_direccion, tipo, principal, direccion, cod_pais, cod_ciudad, observacion,numero)
          values
            (v_cod_persona, 1, 'P', 'S', v_direccion, 1, v_cod_ciudad, v_obs_direccion,:NEW.nro_direccion);

          -- direccion de envios
          insert into ge_dir_envios
          (cod_persona, tip_envio, referencia, nro_cuenta, observacion)
          Values
          (v_cod_persona,'D',1, NULL, null);


        exception
          when others then
            raise_application_error(-20015,'Error al insertar datos en BA_DIRECCIONES. Documento Nro='||:NEW.nro_cedula||' '||sqlerrm);
        end;
        v_cod_dir_laboral := 2;
      else
        v_cod_dir_laboral := 1;
      end if;
      -- direccion laboral
      begin
          v_lugar := '5-Insert BA_DIRECCIONES';
        insert into ba_direcciones
          (cod_persona, cod_direccion, tipo, principal, direccion, cod_pais, cod_ciudad,
          numero)
        select v_cod_persona, v_cod_dir_laboral, tipo, 'N', direccion, cod_pais, cod_ciudad,
        numero
          from ba_direcciones
         where cod_persona = v_emp_cod_persona
           and tipo = 'L'
           and rownum = 1;
        if sql%rowcount = 0 then -- no tiene direcion laboral
          v_cod_dir_laboral := null;
        end if;
        if v_cod_dir_laboral = 1 then
          update ba_direcciones
             set principal = 'S'
           where cod_persona = v_cod_persona
             and cod_direccion = v_cod_dir_laboral;
        end if;
      exception
        when others then
          raise_application_error(-20000,'Error al insertar direccion laboral. Nro Documento='||:NEW.nro_cedula||' '||sqlerrm);
      end;
      -- ba_telefonos
      if :NEW.telefono is not null then
          v_lugar := '6-Telefono';
        if :NEW.telefono like '09%' then
          v_area := substr(:NEW.telefono,1,4);
          v_tipo := 'C';
          v_num_telefono := substr(substr(:NEW.telefono,5),1,10);
        else
          v_area := null;
          v_tipo := 'B';
          v_num_telefono := substr(:NEW.telefono,1,10);
        end if;
        begin
            v_lugar := '7-Insert BA_TELEFONOS';
          insert into ba_telefonos
            (cod_persona, tipo, tip_linea, telefono, principal, area, cod_telefono)
          values
            (v_cod_persona, 'P', v_tipo, v_num_telefono, 'S',v_area, 1);
        exception
          when others then
            raise_application_error(-20016,'Error al insertar datos en BA_TELEFONOS. Nro Documento='||:NEW.nro_cedula||' '||sqlerrm);
        end;
        v_cod_tel_laboral := 2;
      else
        v_cod_tel_laboral := 1;
      end if;
      -- telefono laboral
      begin
          v_lugar := '8-Insert BA_TELEFONOS';
        insert into ba_telefonos
          (cod_persona, tipo, tip_linea, telefono, principal, area, cod_telefono)
        select v_cod_persona, tipo, tip_linea, telefono, 'N', area, v_cod_tel_laboral
          from ba_telefonos
         where cod_persona = v_emp_cod_persona
           and tipo = 'L'
           and rownum = 1;
        if sql%rowcount = 0 then -- no tiene telefono laboral
          v_cod_tel_laboral := null;
        end if;
        if v_cod_tel_laboral = 1 then
          update ba_telefonos
             set principal = 'S'
           where cod_persona = v_cod_persona
             and cod_telefono = v_cod_tel_laboral;
        end if;
      exception
        when others then
          raise_application_error(-20000,'Error al insertar telefono laboral. Nro Documento='||:NEW.nro_cedula||' '||sqlerrm);
      end;
      begin
        -- Perfil de cliente - Origen de fondos - Proposito de la cuenta
            v_lugar := '9-Insert CR_INF_FONDOS';
        insert into cr_inf_fondos
          (cod_persona, fon_salario, pro_ingresos)
        values
          (v_cod_persona, 'S', 'S');
        -- Perfil de cliente - Actividades esperadas
            v_lugar := '10-Insert CR_ACT_ESPERADAS';
        insert into cr_act_esperadas
          (cod_persona, fecha, cod_moneda, can_tra_debito, can_tra_credito, mto_pro_debito, mto_pro_credito)
        values
          (v_cod_persona, v_fec_actual,'GS', 20, 20, :NEW.sueldo, :NEW.sueldo);
        -- Perfil de cliente - Tipo de operaciones
            v_lugar := '11-Insert CR_PER_TIP_OPERACIONES';
        insert into cr_per_tip_operaciones
          (cod_persona, cod_modulo, cod_modalidad)
        values
          (v_cod_persona, 4, 41);
      exception
        when others then
          raise_application_error(-20000,'Error al insertar perfil de cliente. Nro Documento='||:NEW.nro_cedula||' '||sqlerrm);
      end;
    else
      -- Si la persona existe carga la variable
      v_cod_persona := v_codigo;
    end if;
    -- ** carga o actualizacion de sueldos **
    begin
        v_lugar := '12-Concepto';
      select cod_concepto
        into v_cod_concepto
        from cr_con_ing_egr
       where tipo = 'I'
         AND rtrim(ltrim(descripcion)) = 'SUELDO';
    exception
      when others then
        raise_application_error(-20017,'Error al buscar el concepto del Ingreso. Nro Documento='||:NEW.nro_cedula||' '||sqlerrm);
    end;
    begin
        v_lugar := '13-Insert CR_PER_ING_EGRESOS';
      insert into cr_per_ing_egresos
        (cod_persona, cod_concepto, ing_egreso, importe)
      values
        (v_cod_persona, v_cod_concepto, 'I', :NEW.sueldo);
    exception
      when dup_val_on_index then
         update cr_per_ing_egresos
            set importe = :NEW.sueldo
          where cod_persona = v_cod_persona
            and cod_concepto = v_cod_concepto
            and ing_egreso = 'I';
      when others then
        raise_application_error(-20018,'Error al insertar datos en CR_PER_ING_EGRESOS . Nro Documento='||:NEW.nro_cedula||' '||sqlerrm);
    end;
    -- **CLIENTES** --
    --*
    --*  Igual que el form
    --*
    if v_cli_existe = 'N' then
      -- Traer oficina del oficial por defecto
      Begin
         Select cod_oficina
           into v_cod_ofi_oficial
           from ta_pag_sue_ruc_tmp;
        Exception
          when no_data_found then
            raise_application_error(-20010,'Error al traer la empresa. Verifique el proceso de importaciÛn de la empresa : '||' '||sqlerrm);
      End;
      v_cod_usu_oficial := fug_obt_pardinamico( 'COD_USU_OFI_DEFECTO',null,null,null,v_cod_ofi_oficial );
      begin
        insert into ge_clientes
          (cod_persona, cod_oficina, cod_usu_oficial, cod_departamento, tip_extracto, cod_seg_cliente,residente,cod_sec_contable,cod_tip_deudor)
        values
          (v_cod_persona, v_cod_oficina, v_cod_usu_oficial, 11, 'N', v_cod_seg_cliente,'S','N',2);
      exception
        when others then
          raise_application_error(-20021,'Error al insertar datos en GE_CLIENTES. Documento Nro='||:NEW.nro_cedula||' '||sqlerrm);
      end;
    else
      begin
        v_lugar := '15-Update GE_CLIENTES';
        update ge_clientes
           set cod_seg_cliente = v_cod_seg_cliente
         where cod_persona = v_cod_persona;
      exception
        when others then
          raise_application_error(-20022,'Error al modificar datos en GE_CLIENTES. Documento Nro='||:NEW.nro_cedula||' '||sqlerrm);
      end;
    end if;
    -- Relacion laboral con la Empresa
    -- **veo si tiene cargada la informacion laboral
    If  :new.cod_empresa is not null then
      declare
         v_lug_trabajo varchar2(100);
      begin
          v_lugar := '14-LUG_TRABAJO';
         --Traer descripcion de Entes
         Begin
           select descripcion
             into v_lug_trabajo
             from ge_entes
            where cod_ente = :new.cod_empresa;
         Exception
           When others then
             raise_application_error(-20022,'Error al traer datos de GE_ENTES. Cod.Empresa='||:new.cod_empresa||' '||sqlerrm);
         End;
         --Traer concepto
         begin
           select cod_concepto
             into v_cod_concepto
             from cr_con_ing_egr
            where tipo = 'I'
              AND rtrim(ltrim(descripcion)) = 'SUELDO';
         exception
           when others then
             raise_application_error(-20017,'Error al buscar el concepto del Ingreso. Nro Documento='||:NEW.nro_cedula||' '||sqlerrm);
         end;
         --Actualizar informacion Laboral
         update cr_inf_laborales
            set mto_ingreso = :new.sueldo,
                fec_ingreso = :new.fec_ingreso
          where cod_persona = v_cod_persona
            and actual = 'S'
            and lug_trabajo = v_lug_trabajo
            and cod_moneda = 'GS';
         if sql%notfound then
            insert into cr_inf_laborales
               (cod_persona, nro_secuencia, lug_trabajo, tip_cargo, tip_ingreso, actual, cod_moneda, mto_ingreso,
               observacion, fec_ingreso, cod_ramo, tip_empleo, cod_direccion, cod_telefono)
            values
               (v_cod_persona, 999, v_lug_trabajo, v_cod_cargo, v_cod_concepto, 'S', 'GS', :new.sueldo,'PLAN SUELDO',
                :new.fec_ingreso, 28, 'D', v_cod_dir_laboral, v_cod_tel_laboral);
         end if;
      exception
         when others then
           raise_application_error(-20000,'Error al crear Informacion laboral '||sqlerrm);
      end;
    End if;
exception
   when others then
     if sqlcode < -20000  then
         raise;
     else
        raise_application_error(-20000,'Alta Masiva de Personas ' || sqlerrm);
     end if;
END;
/

