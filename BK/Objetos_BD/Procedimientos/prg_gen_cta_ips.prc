create or replace procedure it.prg_gen_cta_ips(p_fecha            in date,
                                               p_cod_empresa      in number,
                                               p_cod_oficina      in number,
                                               p_cod_usu_oficial  in varchar2,
                                               p_cod_departamento in number,
                                               p_tip_extracto     in varchar2,
                                               p_cod_moneda       in varchar2) is
  v_lugar              varchar2(50);
  v_nro_sec_movimiento ge_movimientos.nro_secuencia%type := 0;
  v_direccion          ge_par_generales.dir_correo%type := fug_obt_pardinamico('DIR_ENV_MAI_ALT_PERSONA');
  v_cod_seg_cliente    ge_clientes.cod_seg_cliente%type := FUG_OBT_PARENTES(p_cod_empresa,
                                                                            'COD_SEG_CLIENTE');
  v_cod_modulo         ah_cta_vistas.cod_modulo%type := 3;
  v_cod_modalidad      ah_cta_vistas.cod_modalidad%type := 31;
  v_tip_capitalizacion ah_cta_vistas.tip_capitalizacion%type; -- parametrizar
  v_cod_ofi_origen     ge_movimientos.cod_ofi_origen%type;

  v_piz_tasa_min      ge_tas_fechas.val_minimo%type;
  v_piz_tasa_max      ge_tas_fechas.val_maximo%type;
  v_piz_tasa_actual   ge_tas_fechas.val_tasa%type;
  v_cod_sub_modalidad ge_tas_fechas.cod_sub_modalidad%type := fug_obt_pardinamico('COD_SUB_MAD_AHO_VISTA');
  v_fec_actual        ge_calendarios.fec_actual%type := pag_cal.fu_obt_fec_actual(3);
  v_cod_tasa          ah_cta_vistas.cod_tasa%type;
  v_estado            ah_cta_vistas.estado%type := 'A'; --
  v_err_cir exception;

  cursor tem is
    select c.*
      from it.ge_cta_ips_emp_tmp c
     where c.cod_empresa = p_cod_empresa
       and c.error is null;

  function lf_obt_cod_documento(p_abreviatura   ba_tip_documentos.abreviatura%type,
                                p_nro_documento ge_cta_ips_emp_tmp.nro_cedula%type,
                                p_error         in out varchar2,
                                p_desc_error    in out varchar2)
    return ba_tip_documentos.cod_tip_documento%type is
    lv_cod_tip_documento ba_tip_documentos.cod_tip_documento%type;
  begin
    begin
      --obtenemos el código del tipo de documento
      select cod_tip_documento
        into lv_cod_tip_documento
        from ba_tip_documentos
       where abreviatura = p_abreviatura;
      p_error := 'N';
      return lv_cod_tip_documento;
    exception
      when no_data_found then
        p_error      := 'S';
        p_desc_error := 'Tipo de documento no registrado. Documento Nro=' ||
                        p_nro_documento || ' ' || sqlerrm;
      when others then
        p_error      := 'S';
        p_desc_error := 'Error al buscar tipo documento. Documento Nro=' ||
                        p_nro_documento || ' ' || sqlerrm;
    end;
  end;

  function lf_obt_cod_persona(p_cod_tip_documento ba_personas.cod_tip_documento%type,
                              p_nro_documento     ba_personas.nro_documento%type,
                              p_error             in out varchar2,
                              p_desc_error        in out varchar2)
    return varchar2 is
    v_codigo ba_personas.cod_persona%type;
  begin
    -- Busca la persona
    begin
      select p.cod_persona
        into v_codigo
        from ba_personas p
       where p.cod_tip_documento = p_cod_tip_documento
         and p.nro_documento = p_nro_documento;
      p_error := 'N';
    exception
      when no_data_found then
        p_error  := 'N';
        v_codigo := null;
      when others then
        p_error      := 'S';
        p_desc_error := 'Error al buscar cod. personas. Nro. doc.: ' ||
                        p_nro_documento || ' ' || sqlerrm;
    end;
    return v_codigo;
  end;
  function lf_es_cliente(p_cod_persona ba_personas.cod_persona%type,
                         p_error       in out varchar2,
                         p_desc_error  in out varchar2) return varchar2 is
    v_es_cliente varchar2(1);
  begin
  
    begin
      --buscamos el cod cliente
      select 'S'
        into v_es_cliente
        from ge_clientes c
       where c.cod_persona = p_cod_persona;
      p_error := 'N';
    exception
      when no_data_found then
        p_error      := 'N';
        v_es_cliente := 'N';
      when others then
        p_error      := 'S';
        p_desc_error := 'Error al buscar cliente. Cod. Per.: ' ||
                        p_cod_persona || ' ' || sqlerrm;
    end;
    return v_es_cliente;
  end;
  function lf_tipo_persona(pv_tip_documento ba_personas.cod_tip_documento%type,
                           p_error          in out varchar2,
                           p_desc_error     in out varchar2)
    return ba_personas.tipo%type is
    vv_tipo ba_personas.tipo%type;
  begin
    select d.tip_persona
      into vv_tipo
      from ba_tip_documentos d
     where d.cod_tip_documento = pv_tip_documento;
  
    if nvl(vv_tipo, 'X') = 'F' then
      return 'F';
    else
      return 'J';
    end if;
    p_error := 'N';
  exception
    when others then
      p_error      := 'S';
      p_desc_error := 'Error al buscar el tipo de persona. Cod. Per.: ' ||
                      pv_tip_documento || ' ' || sqlerrm;
  end;

  /*insertar la persona*/
  procedure lp_ins_ba_personas(RP_BPERS       in BA_PERSONAS%rowtype,
                               Pv_COD_PERSONA in out BA_PERSONAS.COD_PERSONA%type,
                               p_error        in out varchar2,
                               p_desc_error   in out varchar2) is
  begin
    begin
      select cod_persona
        into Pv_COD_PERSONA
        from ba_personas
       where cod_tip_documento = rp_bpers.cod_tip_documento
         and nro_documento = rp_bpers.nro_documento;
    exception
      when no_data_found then
        Pv_COD_PERSONA := null;
    end;
    if Pv_COD_PERSONA is null then
      --- No existe la persona
      select s_cod_persona.nextval into Pv_COD_PERSONA from dual;
    
      insert into ba_personas
        (cod_persona,
         nom_completo,
         tipo,
         cod_tip_documento,
         nro_documento,
         cod_pais)
      values
        (Pv_COD_PERSONA,
         rp_bpers.nom_completo,
         rp_bpers.tipo,
         rp_bpers.cod_tip_documento,
         rp_bpers.nro_documento,
         rp_bpers.cod_pais);
      p_error := 'N';
    else
      p_error      := 'S';
      p_desc_error := 'Persona Existente con Documento ' ||
                      rp_bpers.nro_documento;
    end if;
  
  exception
    when others then
      if sqlcode <= -20000 then
        raise;
      else
        p_error      := 'S';
        p_desc_error := 'Ins.Persona ' || sqlerrm;
      end if;
  end;
  function lf_obt_nombre(p_pri_nombre   varchar2,
                         p_seg_nombre   varchar2,
                         p_pri_apellido varchar2,
                         p_seg_apellido varchar2,
                         p_tamano       number) return varchar2 is
    v_nombre varchar2(120);
  begin
    if length(p_pri_nombre || ' ' || p_seg_nombre || ' ' || p_pri_apellido || ' ' ||
              p_seg_apellido) > p_tamano then
      if length(p_pri_nombre || ' ' || p_pri_apellido || ' ' ||
                p_seg_apellido) > p_tamano then
        if length(p_pri_nombre || ' ' || p_pri_apellido || ' ' ||
                  p_seg_apellido) > p_tamano then
          v_nombre := p_pri_nombre || ' ' || p_pri_apellido;
        else
          v_nombre := trim(p_pri_nombre || ' ' || p_pri_apellido || ' ' ||
                           p_seg_apellido);
        end if;
      else
        v_nombre := trim(p_pri_nombre || ' ' || p_pri_apellido || ' ' ||
                         p_seg_apellido);
      end if;
    else
      v_nombre := trim(p_pri_nombre || ' ' || p_seg_nombre || ' ' ||
                       p_pri_apellido || ' ' || p_seg_apellido);
    end if;
    return v_nombre;
  end;

  function lp_ver_dup_nombre(p_tipo    in varchar2,
                             RP_BPERF  in BA_PER_FISICAS%rowtype,
                             P_TIP_DOC number) return varchar2 is
    v_cantidad number := 0;
  begin
    if p_tipo = 'F' then
      --fisico
      select count(*)
        into v_cantidad
        from ba_per_fisicas b, ba_personas a
       where a.cod_persona = b.cod_persona
         and b.pri_nombre = RP_BPERF.pri_nombre
         and b.seg_nombre = RP_BPERF.seg_nombre
         and b.pri_apellido = RP_BPERF.pri_apellido
         and b.seg_apellido = RP_BPERF.seg_apellido
         and a.cod_tip_documento = p_tip_doc
         and rownum = 1;
    end if;
    if nvl(v_cantidad, 0) > 0 then
      return 'S'; -- ya existe un nombre parecido
    else
      return 'N'; -- no existe nombre
    end if;
  end;

  procedure lp_ins_ba_per_fisicas(PP_COD_PERSONA in BA_PER_FISICAS.COD_PERSONA%type,
                                  RP_BPERF       in BA_PER_FISICAS%rowtype,
                                  p_error        in out varchar2,
                                  p_desc_error   in out varchar2) is
    vv_cod_persona ba_personas.cod_persona%type;
  begin
    select cod_persona
      into vv_cod_persona
      from ba_per_fisicas
     where cod_persona = PP_COD_PERSONA;
    --- Actualizar
    update ba_per_fisicas
       set pri_nombre   = rp_bperf.pri_nombre,
           seg_nombre   = rp_bperf.seg_nombre,
           pri_apellido = rp_bperf.pri_apellido,
           seg_apellido = rp_bperf.seg_apellido
     where cod_persona = PP_COD_PERSONA;
  exception
    when no_data_found then
      begin
        insert into ba_per_fisicas
          (cod_persona,
           pri_nombre,
           seg_nombre,
           pri_apellido,
           seg_apellido,
           est_civil,
           cod_sexo,
           fec_nacimiento)
        values
          (PP_COD_PERSONA,
           rp_bperf.pri_nombre,
           rp_bperf.seg_nombre,
           rp_bperf.pri_apellido,
           rp_bperf.seg_apellido,
           rp_bperf.est_civil,
           rp_bperf.cod_sexo,
           rp_bperf.fec_nacimiento);
        p_error := 'N';
      exception
        when others then
          p_error      := 'S';
          p_desc_error := 'Ins.ba_per_fisicas' || sqlerrm;
      end;
  end;

  procedure lp_ins_cliente(pr_cli          ge_clientes%rowtype,
                           p_nro_documento ba_personas.nro_documento%type,
                           p_error         in out varchar2,
                           p_desc_error    in out varchar2) is
  
  begin
    insert into ge_clientes
      (cod_persona,
       cod_oficina,
       cod_usu_oficial,
       cod_departamento,
       tip_extracto,
       cod_seg_cliente,
       residente,
       cod_sec_contable,
       cod_tip_deudor)
    values
      (pr_cli.cod_persona,
       pr_cli.cod_oficina,
       pr_cli.cod_usu_oficial,
       pr_cli.cod_departamento,
       pr_cli.tip_extracto,
       pr_cli.cod_seg_cliente,
       pr_cli.residente,
       pr_cli.cod_sec_contable,
       pr_cli.cod_tip_deudor);
    p_error := 'N';
  exception
    when others then
      p_error      := 'S';
      p_desc_error := 'Error al insertar datos en GE_CLIENTES. Documento Nro=' ||
                      p_nro_documento || ' ' || sqlerrm;
  end;

  function lf_obt_cuenta(pvv_cod_persona ba_personas.cod_persona%type)
    return ge_cuentas.nro_cuenta%type is
    v_nrocuenta ge_cuentas.nro_cuenta%type;
  begin
    select c.nro_cuenta
      into v_nrocuenta
      from ah_cta_vistas c, ge_cta_clientes cli
     where c.nro_cuenta = cli.nro_cuenta
       and cli.cod_persona = pvv_cod_persona
       and cli.relacion = 'P'
       and c.cod_modulo = '3'
       and c.estado not in ('C')
       and c.cod_modalidad in ('31', '334')
       and ROWNUM = 1
       and C.COD_ENTE = p_cod_empresa;
  
    return v_nrocuenta;
  exception
    when others then
      return null;
  end;

  procedure pr_obt_tasa(p_cod_modulo    ba_modulos.cod_modulo%type,
                        p_cod_modalidad ge_modalidades.cod_modalidad%type,
                        p_cod_moneda    ba_monedas.cod_moneda%type,
                        p_cod_oficina   ah_cta_vistas.cod_oficina%type,
                        p_fec_apertura  ah_cta_vistas.fec_apertura%type,
                        p_tasa_actual   number,
                        p_cod_tasa      out ah_cta_vistas.cod_tasa%type) is
    v_cod_tasa ah_cta_vistas.cod_tasa%type;
  begin
    begin
      select tf1.cod_tasa
        into v_cod_tasa
        from ge_tasas tf2, ge_tas_fechas tf1
       where tf2.cod_tasa = tf1.cod_tasa
         and nvl(tf1.cod_modulo, p_cod_modulo) = p_cod_modulo
         and tf1.cod_modalidad = p_cod_modalidad
         and tf1.cod_sub_modalidad = v_cod_sub_modalidad
         and nvl(tf1.cod_oficina, p_cod_oficina) = p_cod_oficina
         and nvl(tf1.cod_moneda, p_cod_moneda) = p_cod_moneda
         and tf1.nro_cuenta is null
         and tf1.val_tasa = p_tasa_actual
         and descripcion like '%TASA%'
         and rownum = 1
         and tf1.fec_vigencia =
             (select max(tf2.fec_vigencia)
                from ge_tas_fechas tf2
               where nvl(tf2.cod_modulo, p_cod_modulo) = p_cod_modulo
                 and tf2.cod_modalidad = p_cod_modalidad
                 and tf2.cod_sub_modalidad = v_cod_sub_modalidad
                 and nvl(tf2.cod_oficina, p_cod_oficina) = p_cod_oficina
                 and nvl(tf2.cod_moneda, p_cod_moneda) = p_cod_moneda
                 and tf2.nro_cuenta is null
                 and tf2.cod_tasa = tf1.cod_tasa
                 and fec_vigencia <= p_fec_apertura)
       order by tf1.cod_tasa;
    exception
      when no_data_found then
        begin
          declare
            cursor rango is
              select ra1.cod_tasa
                from ge_tasas ra2, ge_tas_rangos ra1
               where ra2.cod_tasa = ra1.cod_tasa
                 and nvl(ra1.cod_modulo, p_cod_modulo) = p_cod_modulo
                 and ra1.cod_modalidad = p_cod_modalidad
                 and ra1.cod_sub_modalidad = v_cod_sub_modalidad
                 and nvl(ra1.cod_oficina, p_cod_oficina) = p_cod_oficina
                 and nvl(ra1.cod_moneda, p_cod_moneda) = p_cod_moneda
                 and ra1.nro_cuenta is null
                 and ra1.val_tasa = p_tasa_actual
                 and descripcion like '%TASA%'
                 and ra1.fec_vigencia =
                     (select max(ra2.fec_vigencia)
                        from ge_tas_rangos ra2
                       where nvl(ra2.cod_modulo, p_cod_modulo) =
                             p_cod_modulo
                         and ra2.cod_modalidad = p_cod_modalidad
                         and ra2.cod_sub_modalidad = v_cod_sub_modalidad
                         and nvl(ra2.cod_oficina, p_cod_oficina) =
                             p_cod_oficina
                         and nvl(ra2.cod_moneda, p_cod_moneda) =
                             p_cod_moneda
                         and ra2.nro_cuenta is null
                         and ra2.cod_tasa = ra1.cod_tasa
                         and ra2.val_hasta > 0
                         and ra2.fec_vigencia <= p_fec_apertura);
          begin
            for tra in rango loop
              v_cod_tasa := tra.cod_tasa;
              exit;
            end loop;
          end;
        end;
      when too_many_rows then
        v_cod_tasa := null;
    end;
    p_cod_tasa := v_cod_tasa;
  exception
    when others then
      p_cod_tasa := null;
  end;

  procedure lp_act_reg(p_cod_persona ba_personas.cod_persona%type,
                       p_nro_cuenta  ge_cuentas.nro_cuenta%type,
                       p_error       varchar2,
                       p_r_registro  ge_cta_ips_emp_tmp%rowtype) is
  
  begin
    update it.ge_cta_ips_emp_tmp c
       set c.cod_persona    = p_cod_persona,
           c.nro_cta_ahorro = p_nro_cuenta,
           c.error          = p_error
     where c.nro_cedula = p_r_registro.nro_cedula
       and c.cod_empresa = p_r_registro.cod_empresa;
  end;
begin

  begin
    -- inicializamos para que nos deje realizar modificaciones
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;

  v_tip_capitalizacion := fug_obt_pardinamico('AHO_TIP_CAP_DEF',
                                              
                                              3,
                                              v_cod_modalidad,
                                              p_cod_moneda,
                                              null);

  for t in tem loop
    --Recorremos cursor
    declare
      --inicializamos variables que se utilizan por cada iteración
      v_cli_existe        varchar2(1) := 'N';
      v_tas_existe        varchar2(1) := 'N';
      v_ret_existe        varchar2(1) := 'N';
      v_tra_existe        varchar2(1) := 'N';
      v_cod_ofi_ahorro    number(5) := null;
      v_cod_persona       ba_personas.cod_persona%type;
      v_cod_tip_documento ba_tip_documentos.cod_tip_documento%type;
      v_tipo              ba_personas.tipo%type;
      r_person            ba_personas%rowtype;
      r_bperf             ba_per_fisicas%rowtype;
      r_cli               ge_clientes%rowtype;
      v_nro_cuenta        ge_cuentas.nro_cuenta%type;
      v_denominacion      ah_cta_vistas.denominacion%type;
      v_error             varchar2(1);
      v_desc_error        varchar2(1000);
      r_registro          it.ge_cta_ips_emp_tmp%rowtype;
    begin
      --inicializamos
      r_registro := t;
    
      begin
        --buscamos tipo documento
        v_cod_tip_documento := 1;
        --buscamos tipo de persona
        v_tipo := lf_tipo_persona(v_cod_tip_documento,
                                  v_error,
                                  v_desc_error);
        if v_error = 'S' then
          raise v_err_cir;
        end if;
      
      end;
    
      begin
        v_lugar := '1-Datos Persona';
      
        v_cod_persona := lf_obt_cod_persona(v_cod_tip_documento,
                                            t.nro_cedula,
                                            v_error,
                                            v_desc_error);
      
        if v_error = 'S' then
          raise v_err_cir;
        end if;
      end;
    
      begin
      
        --Insertamos persona si es que no existe
        if v_cod_persona is null then
          --nombre
          r_person.nom_completo := lf_obt_nombre(t.pri_nombre,
                                                 t.seg_nombre,
                                                 t.pri_apellido,
                                                 t.seg_apellido,
                                                 120);
          r_person.nom_completo := upper(r_person.nom_completo);
        
          r_person.nro_documento     := t.nro_cedula;
          r_person.cod_tip_documento := v_cod_tip_documento;
          r_person.fec_vto_documento := to_date('01/01/2050', 'dd/mm/yyyy');
          r_person.cod_pais          := 1; --paraguay
        
          if v_tipo = 'F' then
            r_person.tipo          := 'F';
            r_bperf.fec_nacimiento := t.fec_nacimiento;
            --- Desmembrar nombre
            r_bperf.pri_nombre           := upper(t.pri_nombre);
            r_bperf.pri_apellido         := upper(t.pri_apellido);
            r_bperf.seg_nombre           := upper(t.seg_nombre);
            r_bperf.seg_apellido         := upper(t.seg_apellido);
            r_bperf.est_civil            := 'S';
            r_bperf.cod_sexo             := case t.sexo
                                              when 'FEM' then
                                               'F'
                                              when 'FE' then
                                               'F'
                                              else
                                               'M'
                                            end;
            r_bperf.fec_nacimiento       := t.fec_nacimiento;
            r_bperf.cod_pai_nacionalidad := 1; --paraguay
            r_bperf.cod_ciu_nacimiento   := 1; --Asuncion
          else
            v_error      := 'S';
            v_desc_error := 'No permitido para personas juridicas ' ||
                            r_person.nro_documento;
            raise v_err_cir;
          end if;
        
          if lp_ver_dup_nombre(r_person.tipo, r_bperf, v_cod_tip_documento) = 'N' then
            lp_ins_ba_personas(r_person,
                               v_cod_persona,
                               v_error,
                               v_desc_error);
            if v_error = 'S' then
              raise v_err_cir;
            end if;
          
            lp_ins_ba_per_fisicas(v_cod_persona,
                                  r_bperf,
                                  v_error,
                                  v_desc_error);
            if v_error = 'S' then
              raise v_err_cir;
            end if;
          else
            v_error      := 'S';
            v_desc_error := 'nombre duplicado ';
            if v_error = 'S' then
              raise v_err_cir;
            end if;
          end if;
        
        end if;
      end;
      begin
        v_lugar      := '2-Datos Cliente';
        v_cli_existe := lf_es_cliente(v_cod_persona, v_error, v_desc_error);
      
        if v_cli_existe = 'N' then
          r_cli.cod_persona      := v_cod_persona;
          r_cli.cod_oficina      := p_cod_oficina;
          r_cli.cod_usu_oficial  := p_cod_usu_oficial;
          r_cli.cod_departamento := p_cod_departamento;
          r_cli.tip_extracto     := 'N';
          r_cli.cod_seg_cliente  := v_cod_seg_cliente;
          r_cli.residente        := 'S';
          r_cli.cod_sec_contable := 'N';
          r_cli.cod_tip_deudor   := 2;
        
          lp_ins_cliente(r_cli, t.nro_cedula, v_error, v_desc_error);
          if v_error = 'S' then
            raise v_err_cir;
          end if;
        end if;
      
      end;
    
      begin
        v_nro_cuenta := lf_obt_cuenta(v_cod_persona);
      
        if v_nro_cuenta is null then
        
          v_cod_tasa     := 92;
          v_lugar        := '16-CTAAV';
          v_nro_cuenta   := fug_obt_sig_nro_cuenta(v_cod_modulo,
                                                   v_cod_modalidad,
                                                   p_cod_oficina,
                                                   p_cod_moneda,
                                                   v_cod_persona);
          v_denominacion := lf_obt_nombre(t.pri_nombre,
                                          t.seg_nombre,
                                          t.pri_apellido,
                                          t.seg_apellido,
                                          65);
          v_denominacion := upper(v_denominacion);
          -- ah_cta_vistas
          begin
            v_lugar := '18-Insert AH_CTA_VISTAS';
            insert into ah_cta_vistas
              (cod_modulo,
               cod_modalidad,
               cod_oficina,
               nro_cuenta,
               dig_verificador,
               cod_moneda,
               denominacion,
               fre_extracto,
               fec_apertura,
               ret_personalizada,
               tas_personalizada,
               tip_capitalizacion,
               cod_tasa,
               aut_pendiente,
               tra_prohibida,
               cta_combinada,
               estado,
               est_batch,
               cod_sub_modalidad,
               cod_ente,
               reg_firma)
            values
              (v_cod_modulo,
               v_cod_modalidad,
               nvl(v_cod_ofi_ahorro, p_cod_oficina),
               v_nro_cuenta,
               0,
               p_cod_moneda,
               v_denominacion,
               'M',
               p_fecha,
               'N',
               'N',
               1,
               v_cod_tasa,
               'N',
               'N',
               'N',
               'A',
               'A',
               1,
               p_cod_empresa,
               'ALTA MASIVA CUENTA IPS');
          exception
            when others then
              v_error      := 'S';
              v_desc_error := 'Error al insertar datos en AH_CTA_VISTAS. Documento Nro=' ||
                              t.nro_cedula || ' ' || sqlerrm;
              raise v_err_cir;
            
          end;
          begin
            v_lugar := '19-Insert GE_CTA_CLIENTES';
            insert into ge_cta_clientes
              (cod_persona,
               nro_cuenta,
               dig_verificador,
               cod_oficina,
               cod_modulo,
               cod_modalidad,
               relacion)
            values
              (v_cod_persona,
               v_nro_cuenta,
               0,
               nvl(v_cod_ofi_ahorro, p_cod_oficina),
               v_cod_modulo,
               v_cod_modalidad,
               'P');
          exception
            when others then
              v_error      := 'S';
              v_desc_error := 'Error al insertar datos en GE_CTA_CLIENTES. Documento Nro=' ||
                              t.nro_cedula || sqlerrm;
              raise v_err_cir;
          end;
        
          begin
            v_lugar := '21-Oficina';
            select cod_oficina
              into v_cod_ofi_origen
              from ba_usuarios
             where cod_usuario = user;
          exception
            when others then
              v_error      := 'S';
              v_desc_error := 'Error al buscar la Oficina Origen. Documento Nro=' ||
                              t.nro_cedula || ' ' || sqlerrm;
              raise v_err_cir;
          end;
        
          v_nro_sec_movimiento := v_nro_sec_movimiento + 1;
          begin
            v_lugar := '22-Insert GE_MOVIMIENTOS';
            insert into ge_movimientos
              (fecha,
               hora,
               cod_usuario,
               nro_secuencia,
               fec_valor,
               nro_cuenta,
               cod_moneda,
               cod_oficina,
               est_cuenta,
               estado,
               cod_ofi_origen,
               concepto,
               cod_tra_padre,
               cod_mod_padre,
               cod_mad_padre,
               cod_transaccion,
               cod_modulo,
               cod_modalidad)
            values
              (p_fecha,
               to_char(sysdate, 'hh24:mi:ss'),
               user,
               v_nro_sec_movimiento,
               p_fecha,
               v_nro_cuenta,
               p_cod_moneda,
               nvl(v_cod_ofi_ahorro, p_cod_oficina),
               'A',
               'N',
               v_cod_ofi_origen,
               'Cambio de Estado',
               401,
               v_cod_modulo,
               v_cod_modalidad,
               401,
               v_cod_modulo,
               v_cod_modalidad);
          exception
            when others then
              v_error      := 'S';
              v_desc_error := 'Error al insertar en GE_MOVIMIENTOS. Documento Nro=' ||
                              t.nro_cedula || ' ' || sqlerrm;
              raise v_err_cir;
          end;
          begin
            insert into ge_tra_prohibidas
              (cod_transaccion,
               cod_modulo,
               cod_modalidad,
               nro_cuenta,
               observaciones,
               fec_vencimiento)
            values
              (124,
               3,
               31,
               v_nro_cuenta,
               'Transaccion prohibida para cuenta jubilado',
               to_date('01-01-2100', 'DD-MM-YYYY'));
            insert into ge_tra_prohibidas
              (cod_transaccion,
               cod_modulo,
               cod_modalidad,
               nro_cuenta,
               observaciones,
               fec_vencimiento)
            values
              (250,
               3,
               31,
               v_nro_cuenta,
               'Transaccion prohibida para cuenta jubilado',
               to_date('01-01-2100', 'DD-MM-YYYY'));
            insert into ge_tra_prohibidas
              (cod_transaccion,
               cod_modulo,
               cod_modalidad,
               nro_cuenta,
               observaciones,
               fec_vencimiento)
            values
              (9811,
               3,
               31,
               v_nro_cuenta,
               'Transaccion prohibida para cuenta jubilado',
               to_date('01-01-2100', 'DD-MM-YYYY'));
            insert into ge_tra_prohibidas
              (cod_transaccion,
               cod_modulo,
               cod_modalidad,
               nro_cuenta,
               observaciones,
               fec_vencimiento)
            values
              (595,
               3,
               31,
               v_nro_cuenta,
               'Transaccion prohibida para cuenta jubilado',
               to_date('01-01-2100', 'DD-MM-YYYY'));
          exception
            when others then
              v_error      := 'S';
              v_desc_error := 'Error tra pro ' || t.nro_cedula || ' ' ||
                              sqlerrm;
             raise v_err_cir;
          end;
          begin
            v_lugar := '27-AH_CTA_VISTAS';
            update ah_cta_vistas
               set tra_prohibida = 'S'
             where nro_cuenta = v_nro_cuenta;
          exception
            when others then
              v_error      := 'S';
              v_desc_error := 'Error al modificar AH_CTA_VISTAS. Documento Nro=' ||
                              t.nro_cedula || ' ' || sqlerrm;
              raise v_err_cir;
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
              v_error      := 'S';
              v_desc_error := 'Error al verificar la cuenta. Documento Nro=' ||
                              t.nro_cedula || sqlerrm;
              raise v_err_cir;
          end;
        
        end if;
      
      end;
      lp_act_reg(v_cod_persona, v_nro_cuenta, null, r_registro);
      commit;
    exception
      when v_err_cir then
        rollback;
        lp_act_reg(null, null, v_desc_error, r_registro);
        commit;
      when others then
        rollback;
        lp_act_reg(null, null, 'error: ' || sqlerrm, r_registro);
        commit;
    end;
  end loop;

exception
  when others then
    raise_application_error(-20010,
                            'Error en el proceso de altas masivas ' ||
                            sqlerrm);
  
end;
/
