create or replace package body it.pag_pol is

  -- Funcion para el Alta de Póliza --
  function fu_ins_poliza( p_codigo              in number,      -- Numero de Solicitud en SEBAOT
                          p_cod_persona         in varchar2,    -- Documento de Identidad o RUC en SEBAOT
                          p_cod_ente            in number,      -- Codigo de Compañia en SEBAOT
                          p_cod_oficina         in number,      -- Codigo de Oficina en SEBAOT
                          p_canal               in varchar2,    -- Canal en SEBAOT
                          p_seccion             in varchar2,    -- Seccion de la poliza en SEBAOT
                          p_sub_seccion         in varchar2,    -- Sub-Seccion al que corresponde poliza.
                          p_nro_poliza          in varchar2,    -- Numero de la Poliza.
                          p_producto            in varchar2,    -- Descripcion del Producto
                          p_mto_capital         in number,      -- Capital Asegurado.
                          p_mto_premio          in number,      -- Monto del premio de la poliza.
                          p_mto_prima           in number,      -- Monto de la prima de la poliza.
                          p_cuo_inicial         in number,      -- Monto de la cuota Inicial.
                          p_mto_cuota           in number,      -- Monto de la Cuota
                          p_can_cuota           in number,      -- Cantidad de Cuotas.
                          p_for_pago            in varchar2,    -- Forma de Pago.
                          p_fec_inicial         in date,        -- Fecha de inicio de Vigencia.
                          p_fec_final           in date,        -- Fecha de fin de Vigencia.
                          p_fec_propuesta       in date,        -- Fecha de ingreso de la propuesta.
                          p_fec_envio           in date,        -- Fecha de envio de la poliza a la aseguradora.
                          p_fec_entrega         in date,        -- Fecha de entrega de la poliza al Cliente.
                          p_observaciones       in varchar2,    -- Observaciones (Descripcion del Riesgo).
                          p_estado              in varchar2,    -- Estado de la Poliza en SEBAOT
                          p_referencia          in varchar2,    -- Referencia del numero de la poliza que fue renovada.
                          p_cod_usu_ges_interno in varchar2,    -- Gestor Interno.
                          p_cod_irene           in varchar2,    -- Codigo Irene.
                          p_cod_moneda          in varchar2,    -- Codigo de la moneda
                          p_situacion           in varchar2,    -- Situacion de la Poliza en SEBAOT
                          p_tip_movimiento      in varchar2,    -- Tipo de Movimiento de Seguro en SEBAOT
                          p_tip_anulacion       in varchar2,    -- Tipo de Anulacion en SEBAOT
                          p_cod_sub_seccion     in varchar2 default null     -- codigo de la subseccion o detalle de la poliza
                        ) return typ_mensajeRespuesta is
    -- Variables --
    v_retorno       typ_mensajeRespuesta := typ_mensajeRespuesta();
    rv_gps          ge_pol_seguros%rowtype;
    rv_dep          ge_pol_seguros%rowtype;
    v_nro_error     number;
    v_msj_error     varchar2(200);
    v_par_ente      ge_par_entes.val_parametro%type;
    -- Procedimiento para insertar datos en la tabla GE_POL_SEGUROS --
    procedure lp_ins_ge_pol_seguros(rp_gps ge_pol_seguros%rowtype) is
    begin
      insert into ge_pol_seguros( codigo, cod_persona, cod_ente, cod_oficina,
                                  canal, seccion, sub_seccion, nro_poliza,
                                  producto, mto_capital, mto_premio, mto_prima,
                                  cuo_inicial, mto_cuota, can_cuota, for_pago,
                                  fec_inicial, fec_final, fec_propuesta, fec_envio,
                                  fec_entrega, observaciones, estado, referencia,
                                  cod_irene, cod_moneda, situacion, tip_movimiento,
                                  tip_anulacion, cod_usu_ges_interno, cod_sub_seccion )
      values( rp_gps.codigo, rp_gps.cod_persona, rp_gps.cod_ente, rp_gps.cod_oficina,
              rp_gps.canal, rp_gps.seccion, rp_gps.sub_seccion, rp_gps.nro_poliza,
              rp_gps.producto, rp_gps.mto_capital, rp_gps.mto_premio, rp_gps.mto_prima,
              rp_gps.cuo_inicial, rp_gps.mto_cuota, rp_gps.can_cuota, rp_gps.for_pago,
              rp_gps.fec_inicial, rp_gps.fec_final, rp_gps.fec_propuesta, rp_gps.fec_envio,
              rp_gps.fec_entrega, rp_gps.observaciones, rp_gps.estado, rp_gps.referencia,
              rp_gps.cod_irene, rp_gps.cod_moneda, 1/*rp_gps.situacion*/, rp_gps.tip_movimiento,
              rp_gps.tip_anulacion,rv_gps.cod_usu_ges_interno, rp_gps.cod_sub_seccion);
    end lp_ins_ge_pol_seguros;
    -- Funcion para obtener el Codigo de Persona en ITGF --
    function lf_obt_cod_persona( p_nro_documento in varchar2  -- CI ó RUC
                                ) return ba_personas.cod_persona%type is
      v_cod_persona ba_personas.cod_persona%type;
    begin
      select cod_persona
        into v_cod_persona
        from ba_personas p
       where nro_documento = p_nro_documento;
      return v_cod_persona;
    exception
      when others then
        begin
          select cod_persona
            into v_cod_persona
            from ba_per_documentos p, ba_tip_documentos b
           where p.cod_tip_documento = b.cod_tip_documento
             and nro_documento       = p_nro_documento
             and b.abreviatura       = 'CI';
          return v_cod_persona;
        exception
          when others then
            begin
              select cod_persona
                into v_cod_persona
                from ba_per_documentos p, ba_tip_documentos b
               where p.cod_tip_documento = b.cod_tip_documento
                 and nro_documento       = p_nro_documento
                 and b.abreviatura       = 'RUC';
              return v_cod_persona;
            exception
              when others then
                return null;
            end;
        end;
    end lf_obt_cod_persona;
    -- Funcion para obtener el Codigo de Ente de Seguro en ITGF --
    function lf_obt_ente( p_codigo number -- Codigo en SEBAOT
                         ) return ge_entes.cod_ente%type is
      v_cod_ente ge_entes.cod_ente%type;
    begin
      select a.cod_ente
        into v_cod_ente
        from ge_entes a, ge_par_entes b
       where a.cod_ente = b.cod_ente
         and a.tipo = 'SE'
         and b.parametro = 'COD_ENT_SEBAOT'
         and to_number(trim(b.val_parametro)) = p_codigo;
       return v_cod_ente;
    exception
      when others then
        return null;
    end lf_obt_ente;
    -- Funcion para obtener el valor del Parametro de Ente de Seguro --
    function lf_obt_par_ente( p_cod_ente number, -- Código de Ente en ITGF
                              p_parametro varchar2 -- Parámetro a obtener
                             ) return ge_par_entes.val_parametro%type is
      v_valor ge_par_entes.val_parametro%type;
    begin
      select (trim(b.val_parametro))
        into v_valor
        from ge_entes a, ge_par_entes b
       where a.cod_ente = b.cod_ente
         and a.tipo = 'SE'
         and b.parametro = p_parametro
         and a.cod_ente = p_cod_ente;
       return v_valor;
    exception
      when others then
        return null;
    end lf_obt_par_ente;
    -- Funcion para validar Referencias Generales --
    function lf_obt_referencia( p_dominio varchar2, -- Dominio de la Referencia General
                                p_valor varchar2    -- Valor
                               ) return ba_cod_referencias.val_maximo%type is
      v_valor ba_cod_referencias.val_maximo%type;
    begin
      select trim(val_maximo)
        into v_valor
        from ba_cod_referencias
       where dominio = p_dominio
         and trim(val_minimo) = trim(p_valor);
      return v_valor;
    exception
      when others then
        return null;
    end lf_obt_referencia;
    -- Funcion para obtener el Gestor --
    function lf_obt_gestor( p_valor varchar2 ) return ba_cod_referencias.val_maximo%type is
      v_valor ba_cod_referencias.val_maximo%type;
    begin
      select trim(val_maximo)
        into v_valor
        from ba_cod_referencias
       where dominio = 'COD_GES_SEBAOT'
         and trim(val_minimo) = trim(p_valor);
      return v_valor;
    exception
      when others then
        begin
          select trim(val_maximo)
          into v_valor
          from ba_cod_referencias
         where dominio = 'COD_GES_SEBAOT'
           and trim(val_maximo) = trim(p_valor);
          return v_valor;
        exception
          when others then
            return null;
        end;
    end lf_obt_gestor;
    -- Funcion para validar la Moneda --
    function lf_obt_moneda( p_cod_moneda varchar2
                           ) return ba_monedas.cod_moneda%type is
      v_cod_moneda ba_monedas.cod_moneda%type;
    begin
      select cod_moneda
        into v_cod_moneda
        from ba_monedas
       where cod_moneda = trim(p_cod_moneda);
       return v_cod_moneda;
    exception
      when others then
        return null;
    end lf_obt_moneda;
    --
  /*  lp_ins_error(p_nro_documento varchar2, p_observacion varchar2) is

      begin
        insert into ge_log_polizas
          (nro_documento, observacion)
        values
          (p_nro_documento, p_observacion);
       end lp_ins_error;*/
   procedure lp_ins_error(p_nro_documento varchar2, p_observacion varchar2) is
     v_existe number;
    begin
      select count(*)
        into v_existe
        from ge_log_polizas a
       where a.nro_documento = p_nro_documento;
      if v_existe >= 1 then
        delete ge_log_polizas a
        where a.nro_documento = p_nro_documento;
        insert into ge_log_polizas(nro_documento, observacion)
        values(p_nro_documento, p_observacion);
      else
        insert into ge_log_polizas(nro_documento, observacion)
        values(p_nro_documento, p_observacion);
      end if;
      commit;
    end lp_ins_error;
  begin
    -- Validar que no exista una Solicitud con el mismo Número. --
    begin
      select a.codigo
        into rv_gps.codigo
        from ge_pol_seguros a
       where a.codigo = p_codigo;
      v_nro_error := 1001;
      v_msj_error := 'Solicitud existente.';
      v_retorno.error := 'S';
      v_retorno.nombreRespuesta := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      return v_retorno;
    exception
      when no_data_found then
        rv_gps.codigo := p_codigo;
    end;
    -- Código de Persona --
    if p_cod_persona is not null
      and p_cod_persona != '*' then
        --rv_dep.cod_persona := paw_bel.depurarAlfanumerico(p_cod_persona,10);
        rv_gps.cod_persona := lf_obt_cod_persona(p_cod_persona);
    end if;
    if rv_gps.cod_persona is null then
      v_nro_error     := 1002;
      v_msj_error     := 'No se encuentra el Codigo de Persona en ITGF.';
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
      return v_retorno;
    end if;
    -- Código de Ente --
    if nvl(p_cod_ente,0)>0 then
      rv_gps.cod_ente := lf_obt_ente(p_cod_ente);
      -- Validar Seguro con Convenio con el BBVA --
      if rv_gps.cod_ente is not null then
        v_par_ente := lf_obt_par_ente(rv_gps.cod_ente, 'SEG_POL_ACTIVO');
        if v_par_ente != 'S' then
          rv_gps.cod_ente := null;
        end if;
      end if;
      if rv_gps.cod_ente is null then
        v_nro_error := 1003;
        v_msj_error := 'No se encuentra el Codigo de Ente en ITGF.';
        v_retorno.error                := 'S';
        v_retorno.nombreRespuesta      := 'ERROR';
        v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
        lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
        return v_retorno;
      end if;
    end if;
    -- Código de Oficina --
    if nvl(p_cod_oficina,0)>0 then
      begin
        select to_number(trim(val_maximo))
          into rv_gps.cod_oficina
          from ba_cod_referencias
         where dominio    = 'COD_OFI_SEBAOT'
           and val_minimo = p_cod_oficina;
      exception
        when no_data_found then
          v_nro_error := 1004;
          v_msj_error := 'No se encuentra el Codigo de Oficina en ITGF.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
      end;
    end if;
    -- Código de Canal --
    if p_canal is not null
      and p_canal != '*' then
        rv_gps.canal := lf_obt_referencia('SEC_CANALES', p_canal);
        --DYDMR-5378, se comenta superior, en un futuro se migraran los canales de donde se ofreci? el seguro
        --Sino existe convalidaci?n de canales, entre SEBAOT e ITGF, solo se debe insertar nulo y no rechazar
        /*
        if rv_gps.canal is null then
          v_nro_error := 1005;
          v_msj_error := 'No se encuentra el Codigo de Canal en ITGF.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
        end if;
        */
    end if;
    -- Código de Seccion --
    if p_seccion is not null
      and p_seccion != '*' then
        rv_gps.seccion := lf_obt_referencia('SEC_SEGURO', p_seccion);
        if rv_gps.seccion is null then
          v_nro_error := 1006;
          v_msj_error := 'No se encuentra el Codigo de Seccion en ITGF.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
        end if;
    end if;
    -- Subsección --
    if p_sub_seccion is not null
      and p_sub_seccion != '*' then
        --rv_dep.sub_seccion := paw_bel.depurarAlfanumerico(p_sub_seccion,100,'S');
        rv_gps.sub_seccion := substr(p_sub_seccion,1,100);
    end if;
    
    if p_cod_sub_seccion is not null
       and pat_imp.FU_VAL_NUMERO(p_cod_sub_seccion) is not null then
      rv_gps.cod_sub_seccion := substr(p_cod_sub_seccion,1,4);
    else
      rv_gps.cod_sub_seccion := null;
    end if;
    
    -- Número de Póliza --
    if p_nro_poliza is not null
      and p_nro_poliza != '*' then
          --rv_dep.nro_poliza := paw_bel.depurarAlfanumerico(p_nro_poliza,20);
		  rv_dep.nro_poliza := paw_bel.depurarTextos(p_nro_poliza,30);
          rv_gps.nro_poliza := substr(rv_dep.nro_poliza,1,30);
    end if;
    -- Producto --
    if p_producto is not null
      and p_producto != '*' then
          --rv_dep.producto := paw_bel.depurarAlfanumerico(p_producto,100,'S');
		  rv_dep.producto := paw_bel.depurarTextos(p_producto,100);
          rv_gps.producto := substr(rv_dep.producto,1,100);
    end if;
    -- Monto Capital --
    if nvl(p_mto_capital,0) > 0 then
      rv_gps.mto_capital := p_mto_capital;
    else
	  rv_gps.mto_capital := 0;
	end if;
    -- Monto Premio --
    if nvl(p_mto_premio,0) > 0 then
      rv_gps.mto_premio := p_mto_premio;
    end if;
    -- Monto Prima --
    if nvl(p_mto_prima,0) > 0 then
      rv_gps.mto_prima := p_mto_prima;
    end if;
    -- Monto Cuota Inicial --
    if nvl(p_cuo_inicial,0) > 0 then
      rv_gps.cuo_inicial := p_cuo_inicial;
    end if;
    -- Monto Cuota --
    if nvl(p_mto_cuota,0) > 0 then
      rv_gps.mto_cuota := p_mto_cuota;
    end if;
    -- Cantidad Cuotas --
    if nvl(p_can_cuota,0) > 0 then
      rv_gps.can_cuota := p_can_cuota;
    end if;
    -- Forma de Pago --
    if p_for_pago is not null
      and p_for_pago != '*' then
        rv_gps.for_pago := lf_obt_referencia('FOR_PAG_SEG', p_for_pago);
        if rv_gps.for_pago is null then
          v_nro_error := 1007;
          v_msj_error := 'No se encuentra la Forma de Pago.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
        end if;
    end if;
    -- Fecha Inicio de Vigencia --
    if p_fec_inicial is not null then
      rv_gps.fec_inicial := p_fec_inicial;
    end if;
    -- Fecha Fin de Vigencia --
    if p_fec_final is not null then
      rv_gps.fec_final := p_fec_final;
    end if;
    -- Fecha Propuesta --
    if p_fec_propuesta is not null then
      rv_gps.fec_propuesta := p_fec_propuesta;
    end if;
    -- Fecha Envío --
    if p_fec_envio is not null then
      rv_gps.fec_envio := p_fec_envio;
    end if;
    -- Fecha Entrega --
    if p_fec_entrega is not null then
      rv_gps.fec_entrega := p_fec_entrega;
    end if;
    -- Descripción del Riesgo --
    if p_observaciones is not null
      and p_sub_seccion != '*' then
         --rv_dep.observaciones := paw_bel.depurarAlfanumerico(p_observaciones,2000,'S');
         rv_gps.observaciones := substr(p_observaciones,1,2000);
    end if;
    -- Estado de la Póliza --
    if p_estado is not null
      and p_estado != '*' then
        rv_gps.estado := lf_obt_referencia('EST_POLIZA', p_estado);
        if rv_gps.estado is null then
          v_nro_error := 1008;
          v_msj_error := 'No se encuentra el Estado de la Poliza.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
        end if;
    end if;
    -- Referencia a Póliza renovada --
    if p_referencia is not null
      and p_referencia != '*' then
        --rv_dep.referencia := paw_bel.depurarAlfanumerico(p_referencia,20,'S');
		rv_dep.referencia := paw_bel.depurarTextos(p_referencia,30);
        rv_gps.referencia := substr(rv_dep.referencia,1,30);
    end if;
    -- Gestor
    -- Código Irene
    if p_cod_irene is not null
      and p_cod_irene != '*' then
      --if p_cod_irene in('VIR','VIT','HOR','HOT','SAR','SAT','APR','APT','PMR','PMT') then
        rv_gps.cod_irene := p_cod_irene;
      --end if;
    end if;
    -- Código de Moneda --
    if p_cod_moneda is not null
      and p_cod_moneda != '*' then
        rv_gps.cod_moneda := lf_obt_moneda(p_cod_moneda);
        if rv_gps.cod_moneda is null then
          v_nro_error := 1009;
          v_msj_error := 'No se encuentra el Codigo de Moneda en ITGF.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
        end if;
    end if;
    -- Situación de la Póliza --
    if p_situacion is not null
      and p_situacion != '*' then
        rv_gps.situacion := lf_obt_referencia('SIT_POLIZA', p_situacion);
        if rv_gps.situacion is null then
          v_nro_error := 1010;
          v_msj_error := 'No se encuentra la Situacion.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
        end if;
    end if;
    -- Tipo de Movimiento --
    if p_tip_movimiento is not null
      and p_tip_movimiento != '*' then
        rv_gps.tip_movimiento := lf_obt_referencia('TIP_MOV_POLIZA', p_tip_movimiento);
        if rv_gps.tip_movimiento is null then
          v_nro_error := 1011;
          v_msj_error := 'No se encuentra el Tipo de Movimiento.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
        end if;
    end if;
    -- Tipo de Anulacion --
    if p_tip_anulacion is not null
      and p_tip_anulacion != '*'
        and p_tip_anulacion != 'N'  then
          rv_gps.tip_anulacion := lf_obt_referencia('TIP_ANU_POLIZA', p_tip_anulacion);
          if rv_gps.tip_anulacion is null then
            v_nro_error := 1012;
            v_msj_error := 'No se encuentra el Tipo de Anulacion.';
            v_retorno.error                := 'S';
            v_retorno.nombreRespuesta      := 'ERROR';
            v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
            lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
            return v_retorno;
          end if;
    end if;
    -- Gestor--
    if p_cod_usu_ges_interno is not null
      and p_cod_usu_ges_interno != '*' then
        rv_gps.cod_usu_ges_interno := lf_obt_gestor(p_cod_usu_ges_interno);
      --DYDMR-5378- Sino esta registrado no debe dar error, no se inserta nomas el cod_usu_ges_interno
      /*
      if rv_gps.cod_usu_ges_interno is null then
          
          v_nro_error := 1013;
          v_msj_error := 'No se encuentra el Gestor.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error(p_cod_persona, v_retorno.descripcionRespuesta);
          return v_retorno;
      end if;*/
    end if;
    --borra de la tabla si esta todo ok
    delete ge_log_polizas a
    where a.nro_documento = p_cod_persona;
    -- Insertar datos en la Tabla GE_POL_SEGUROS --
    lp_ins_ge_pol_seguros(rv_gps);
    commit;
    -- Cargar Retorno para Operación Finalizada --
    v_retorno.error                := 'N';
    v_retorno.nombreRespuesta      := 'OK';
    v_retorno.descripcionRespuesta := 'Transaccion aprobada';
    return v_retorno;
  exception
    when others then
      v_nro_error := 1999;
      v_msj_error := substr(SQLERRM,1,200);
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      return v_retorno;
  end fu_ins_poliza;

  -- Funcion para la Actualizacion de la Póliza a Estado Emitida --
  function fu_act_pol_emitida( p_codigo           in number,       -- Número de Solicitud en SEBAOT
                               p_cod_persona      in varchar2,    -- Documento de Identidad o RUC en SEBAOT
                               p_cod_oficina      in number,      -- Código de Oficina en SEBAOT
                               p_seccion          in varchar2,    -- Sección de la póliza en SEBAOT
                               p_sub_seccion      in varchar2,    -- Sub-Sección al que corresponde póliza.
                               p_nro_poliza       in varchar2,    -- Número de la Póliza.
                               p_producto         in varchar2,    -- Descripcion del Producto
                               p_mto_capital      in number,      -- Capital Asegurado.
                               p_mto_premio       in number,      -- Monto del premio de la póliza.
                               p_mto_prima        in number,      -- Monto de la prima de la póliza.
                               p_cuo_inicial      in number,      -- Monto de la cuota Inicial.
                               p_mto_cuota        in number,      -- Monto de la Cuota
                               p_can_cuota        in number,      -- Cantidad de Cuotas.
                               p_for_pago         in varchar2,    -- Forma de Pago.
                               p_fec_inicial      in date,        -- Fecha de inicio de Vigencia.
                               p_fec_final        in date,        -- Fecha de fin de Vigencia.
                               p_fec_entrega      in date,        -- Fecha de entrega de la póliza al Cliente.
                               p_observaciones    in varchar2,    -- Observaciones (Descripción del Riesgo).
                               p_estado           in varchar2,    -- Estado de la Póliza en SEBAOT
                               p_referencia       in varchar2,    -- Referencia del número de la póliza que fué renovada.
                               p_cod_irene        in varchar2,    -- Código Irene.
                               p_cod_moneda       in varchar2,    -- Código de la moneda
                               p_situacion        in varchar2,    -- Situación de la Póliza en SEBAOT
                               p_tip_movimiento   in varchar2,    -- Tipo de Movimiento de Seguro en SEBAOT
                               p_tip_anulacion    in varchar2,     -- Tipo de Anulación en SEBAOT
                               p_fec_emision      in date
                             ) return typ_mensajeRespuesta is
    -- Variables --
    v_retorno       typ_mensajeRespuesta := typ_mensajeRespuesta();
    rv_gps          ge_pol_seguros%rowtype;
    rv_dep          ge_pol_seguros%rowtype;
    v_nro_error     number;
    v_msj_error     varchar2(200);
    -- Procedimiento para actualizar datos en la tabla GE_POL_SEGUROS --
    procedure lp_act_ge_pol_seguros(rp_gps ge_pol_seguros%rowtype) is
    begin
      update ge_pol_seguros
         set cod_persona     = nvl(rp_gps.cod_persona,cod_persona),
             cod_oficina    = nvl(rp_gps.cod_oficina,cod_oficina),
             seccion        = nvl(rp_gps.seccion,seccion),
             sub_seccion    = nvl(rp_gps.sub_seccion,sub_seccion),
             nro_poliza     = nvl(rp_gps.nro_poliza,nro_poliza),
             producto       = nvl(rp_gps.producto,producto),
             mto_capital    = nvl(rp_gps.mto_capital,mto_capital),
             mto_premio     = nvl(rp_gps.mto_premio,mto_premio),
             mto_prima      = nvl(rp_gps.mto_prima,mto_prima),
             cuo_inicial    = nvl(rp_gps.cuo_inicial,cuo_inicial),
             mto_cuota      = nvl(rp_gps.mto_cuota,mto_cuota),
             can_cuota      = nvl(rp_gps.can_cuota,can_cuota),
             for_pago       = nvl(rp_gps.for_pago,for_pago),
             fec_inicial    = nvl(rp_gps.fec_inicial,fec_inicial),
             fec_final      = nvl(rp_gps.fec_final,fec_final),
             fec_entrega    = nvl(rp_gps.fec_entrega,fec_entrega),
             observaciones  = nvl(rp_gps.observaciones,observaciones),
             estado         = nvl(rp_gps.estado,estado),
             referencia     = nvl(rp_gps.referencia,referencia),
             cod_irene      = nvl(rp_gps.cod_irene,cod_irene),
             cod_moneda     = nvl(rp_gps.cod_moneda,cod_moneda),
             situacion      = nvl(rp_gps.situacion,situacion),
             tip_movimiento = nvl(rp_gps.tip_movimiento,tip_movimiento),
             tip_anulacion  = nvl(rp_gps.tip_anulacion,tip_anulacion),
             fec_emision    = nvl(rp_gps.fec_emision,fec_emision)
       where codigo         = rp_gps.codigo;
    end lp_act_ge_pol_seguros;
    -- Funcion para obtener el Código de Persona en ITGF --
    function lf_obt_cod_persona( p_nro_documento in varchar2  -- CI ó RUC
                                ) return ba_personas.cod_persona%type is
      v_cod_persona ba_personas.cod_persona%type;
    begin
      select cod_persona
        into v_cod_persona
        from ba_personas p
       where nro_documento = p_nro_documento;
      return v_cod_persona;
    exception
      when others then
        begin
          select cod_persona
            into v_cod_persona
            from ba_per_documentos p, ba_tip_documentos b
           where p.cod_tip_documento = b.cod_tip_documento
             and nro_documento       = p_nro_documento
             and b.abreviatura       = 'CI';
          return v_cod_persona;
        exception
          when others then
            begin
              select cod_persona
                into v_cod_persona
                from ba_per_documentos p, ba_tip_documentos b
               where p.cod_tip_documento = b.cod_tip_documento
                 and nro_documento       = p_nro_documento
                 and b.abreviatura       = 'RUC';
            exception
              when others then
                return null;
            end;
        end;
    end lf_obt_cod_persona;
    -- Funcion para validar Referencias Generales --
    function lf_obt_referencia( p_dominio varchar2, -- Dominio de la Referencia General
                                p_valor varchar2    -- Valor
                               ) return ba_cod_referencias.val_maximo%type is
      v_valor ba_cod_referencias.val_maximo%type;
    begin
      select trim(val_maximo)
        into v_valor
        from ba_cod_referencias
       where dominio = p_dominio
         and trim(val_minimo) = trim(p_valor);
      return v_valor;
    exception
      when others then
        return null;
    end lf_obt_referencia;
    -- Funcion para validar la Moneda --
    function lf_obt_moneda( p_cod_moneda varchar2
                           ) return ba_monedas.cod_moneda%type is
      v_cod_moneda ba_monedas.cod_moneda%type;
    begin
      select cod_moneda
        into v_cod_moneda
        from ba_monedas
       where cod_moneda = trim(p_cod_moneda);
       return v_cod_moneda;
    exception
      when others then
        return null;
    end lf_obt_moneda;
    --
  begin
    -- Validar que exista una Solicitud con el Número recibido --
    begin
      select a.codigo
        into rv_gps.codigo
        from ge_pol_seguros a
       where a.codigo = p_codigo;
      rv_gps.codigo := p_codigo;
    exception
      when no_data_found then
        v_nro_error := 2001;
        v_msj_error := 'Solicitud inexistente.';
        v_retorno.error                := 'S';
        v_retorno.nombreRespuesta      := 'ERROR';
        v_retorno.descripcionRespuesta := substr('Error al actualizar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
        return v_retorno;
    end;
    -- Código de Persona --No hace falta verificar por codigo de persona
    /*if p_cod_persona is not null
      and p_cod_persona != '*' then
        rv_dep.cod_persona := paw_bel.depurarAlfanumerico(p_cod_persona,10);
        rv_gps.cod_persona := lf_obt_cod_persona(rv_dep.cod_persona);
    end if;
    if rv_gps.cod_persona is null then
      v_nro_error := 2002;
      v_msj_error := 'No se encuentra el Codigo de Persona en ITGF.';
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al actualizar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      return v_retorno;
    end if; */
    -- Código de Oficina --
    if nvl(p_cod_oficina,0)>0 then
      begin
        select to_number(trim(val_maximo))
          into rv_gps.cod_oficina
          from ba_cod_referencias
         where dominio    = 'COD_OFI_SEBAOT'
           and val_minimo = p_cod_oficina;
      exception
        when no_data_found then
          v_nro_error := 2003;
          v_msj_error := 'No se encuentra el Codigo de Oficina en ITGF.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
      end;
    end if;
    -- Código de Seccion --
    if p_seccion is not null
      and p_seccion != '*' then
        rv_gps.seccion := lf_obt_referencia('SEC_SEGURO', p_seccion);
        if rv_gps.seccion is null then
          v_nro_error := 2004;
          v_msj_error := 'No se encuentra el Codigo de Seccion en ITGF.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
        end if;
    end if;
    -- Subsección --
    if p_sub_seccion is not null
      and p_sub_seccion != '*' then
        --rv_dep.sub_seccion := paw_bel.depurarAlfanumerico(p_situacion,10,'S');
        --rv_gps.sub_seccion := substr(p_situacion,1,100);
		rv_gps.sub_seccion := p_situacion;
    end if;
    -- Número de Póliza --
    if p_nro_poliza is not null
      and p_nro_poliza != '*' then
        --rv_gps.nro_poliza := substr(p_nro_poliza,1,10);
		rv_gps.nro_poliza := p_nro_poliza;
    end if;
    -- Producto --
    if p_producto is not null
      and p_producto != '*' then
        --rv_dep.producto := paw_bel.depurarAlfanumerico(p_producto,10,'S');
		rv_dep.producto := p_producto;
        --rv_gps.producto := substr(rv_dep.producto,1,100);
		rv_gps.producto := rv_dep.producto;
    end if;
    -- Monto Capital --
    if nvl(p_mto_capital,0) > 0 then
      rv_gps.mto_capital := p_mto_capital;
    end if;
    -- Monto Premio --
    if nvl(p_mto_premio,0) > 0 then
      rv_gps.mto_premio := p_mto_premio;
    end if;
    -- Monto Prima --
    if nvl(p_mto_prima,0) > 0 then
      rv_gps.mto_prima := p_mto_prima;
    end if;
    -- Monto Cuota Inicial --
    if nvl(p_cuo_inicial,0) > 0 then
      rv_gps.cuo_inicial := p_cuo_inicial;
    end if;
    -- Monto Cuota --
    if nvl(p_mto_cuota,0) > 0 then
      rv_gps.mto_cuota := p_mto_cuota;
    end if;
    -- Cantidad Cuotas --
    if nvl(p_can_cuota,0) > 0 then
      rv_gps.can_cuota := p_can_cuota;
    end if;
    -- Forma de Pago --
    if p_for_pago is not null
      and p_for_pago != '*' then
        rv_gps.for_pago := lf_obt_referencia('FOR_PAG_SEG', p_for_pago);
        if rv_gps.for_pago is null then
          v_nro_error := 2005;
          v_msj_error := 'No se encuentra la Forma de Pago.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
        end if;
    end if;
    -- Fecha Inicio de Vigencia --
    if p_fec_inicial is not null then
      rv_gps.fec_inicial := p_fec_inicial;
    end if;
    -- Fecha Fin de Vigencia --
    if p_fec_final is not null then
      rv_gps.fec_final := p_fec_final;
    end if;
    -- Fecha Entrega --
    if p_fec_entrega is not null then
      rv_gps.fec_entrega := p_fec_entrega;
    end if;
    -- Fecha Emisión --
    if p_fec_emision is not null then
      rv_gps.fec_emision := p_fec_emision;
    end if;
    -- Descripción del Riesgo --
    if p_observaciones is not null
      and p_observaciones != '*' then
      --rv_dep.observaciones := paw_bel.depurarAlfanumerico(p_observaciones,10,'S');
      rv_gps.observaciones := substr(p_observaciones,1,2000);
    end if;
    -- Estado de la Póliza --
    if p_estado is not null
      and p_estado != '*' then
        rv_gps.estado := lf_obt_referencia('EST_POLIZA', p_estado);
        if rv_gps.estado is null then
          v_nro_error := 2006;
          v_msj_error := 'No se encuentra el Estado de la Poliza.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
        end if;
    end if;
    -- Referencia a Póliza renovada --
    if p_referencia is not null
      and p_referencia != '*' then
        rv_gps.referencia := substr(p_referencia,1,30);
    end if;
    -- Código Irene
    if p_cod_irene is not null
      and p_cod_irene != '*' then
      --if p_cod_irene in('VIR','VIT','HOR','HOT','SAR','SAT','APR','APT','PMR','PMT') then
        rv_gps.cod_irene := p_cod_irene;
      --end if;
    end if;
    -- Código de Moneda --
    if p_cod_moneda is not null
      and p_cod_moneda != '*' then
        rv_gps.cod_moneda := lf_obt_moneda(p_cod_moneda);
        if rv_gps.cod_moneda is null then
          v_nro_error := 2007;
          v_msj_error := 'No se encuentra el Codigo de Moneda en ITGF.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
        end if;
    end if;
    -- Situación de la Póliza --
    if p_situacion is not null
      and p_situacion != '*' then
        rv_gps.situacion := lf_obt_referencia('SIT_POLIZA', p_situacion);
        if rv_gps.situacion is null then
          v_nro_error := 2008;
          v_msj_error := 'No se encuentra la Situacion.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
        end if;
    end if;
    -- Tipo de Movimiento --
    if p_tip_movimiento is not null
      and p_tip_movimiento != '*' then
        rv_gps.tip_movimiento := lf_obt_referencia('TIP_MOV_POLIZA', p_tip_movimiento);
        if rv_gps.tip_movimiento is null then
          v_nro_error := 2009;
          v_msj_error := 'No se encuentra el Tipo de Movimiento.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
        end if;
    end if;
    -- Tipo de Anulacion --
    if p_tip_anulacion is not null
      and p_tip_anulacion != '*'
        and p_tip_anulacion != 'N'  then
          rv_gps.tip_anulacion := lf_obt_referencia('TIP_ANU_POLIZA', p_tip_anulacion);
          if rv_gps.tip_anulacion is null then
            v_nro_error := 2010;
            v_msj_error := 'No se encuentra el Tipo de Anulacion.';
            v_retorno.error                := 'S';
            v_retorno.nombreRespuesta      := 'ERROR';
            v_retorno.descripcionRespuesta := substr('Error al ingresar la poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
            return v_retorno;
          end if;
    end if;
    -- Actualizar datos en la Tabla GE_POL_SEGUROS --
    lp_act_ge_pol_seguros(rv_gps);
    commit;
    -- Cargar Retorno para Operación Finalizada --
    v_retorno.error                := 'N';
    v_retorno.nombreRespuesta      := 'OK';
    v_retorno.descripcionRespuesta := 'Transaccion aprobada';
    return v_retorno;
  exception
    when others then
      v_nro_error := 2999;
      v_msj_error := substr(SQLERRM,1,200);
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al actualizar la poliza.. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      return v_retorno;
  end fu_act_pol_emitida;

  -- Funcion para la Actualizacion de la Situacion de la Póliza --
  function fu_act_sit_poliza( p_codigo      in number,     -- Número de Solicitud en SEBAOT
                              p_situacion   in varchar2   -- Situación de la Póliza en SEBAOT
                             ) return typ_mensajeRespuesta is
    -- Variables --
    v_retorno       typ_mensajeRespuesta := typ_mensajeRespuesta();
    v_nro_error     number;
    v_msj_error     varchar2(200);
    v_codigo        ge_pol_seguros.codigo%type;
    v_situacion     ge_pol_seguros.situacion%type;
    v_estado        ge_pol_seguros.estado%type;
    -- Funcion para validar Referencias Generales --
    function lf_obt_referencia( p_dominio varchar2, -- Dominio de la Referencia General
                                p_valor varchar2    -- Valor
                               ) return ba_cod_referencias.val_maximo%type is
      v_valor ba_cod_referencias.val_maximo%type;
    begin
      select trim(val_maximo)
        into v_valor
        from ba_cod_referencias
       where dominio = p_dominio
         and trim(val_minimo) = trim(p_valor);
      return v_valor;
    exception
      when others then
        return null;
    end lf_obt_referencia;
    -- Procedimiento para actualizar datos en la tabla GE_POL_SEGUROS --
    procedure lp_act_ge_pol_seguros( p_codigo    ge_pol_seguros.codigo%type,       -- Número de Solicitud
                                     p_situacion ge_pol_seguros.situacion%type,  -- Situación de la Póliza
                                     p_estado    ge_pol_seguros.estado%type
                                    ) is
    begin
      update ge_pol_seguros
         set situacion = nvl(p_situacion,situacion),
             estado = nvl(p_estado,estado)
       where codigo = p_codigo;
    end lp_act_ge_pol_seguros;
  begin
    -- Validar que exista una Solicitud con el Número recibido --
    begin
      select a.codigo
        into v_codigo
        from ge_pol_seguros a
       where a.codigo = p_codigo;
    exception
      when no_data_found then
        v_nro_error := 3001;
        v_msj_error := 'Solicitud inexistente.';
        v_retorno.error                := 'S';
        v_retorno.nombreRespuesta      := 'ERROR';
        v_retorno.descripcionRespuesta := substr('Error al procesar Situacion. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
        return v_retorno;
    end;
    -- Situación de la Póliza --
    if p_situacion is not null
      and p_situacion != '*' then
        v_situacion := lf_obt_referencia('SIT_POLIZA', p_situacion);
        if v_situacion is null then
          v_nro_error := 3002;
          v_msj_error := 'No se encuentra la Situacion.';
          v_retorno.error                := 'S';
          v_retorno.nombreRespuesta      := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al procesar Situacion. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          return v_retorno;
        end if;
    end if;
    if p_situacion = '2' then -- Vencida
      v_estado := '3';
    elsif p_situacion = '3' then --Anulada
      v_estado := '4';
    else
      v_estado := null;
    end if;
    -- Actualizar datos en la Tabla GE_POL_SEGUROS --
    lp_act_ge_pol_seguros(v_codigo, v_situacion, v_estado);
    commit;
    -- Cargar Retorno para Operacion Finalizada --
    v_retorno.error                := 'N';
    v_retorno.nombreRespuesta      := 'OK';
    v_retorno.descripcionRespuesta := 'Transaccion aprobada';
    return v_retorno;
  exception
    when others then
      v_nro_error := 3999;
      v_msj_error := substr(SQLERRM,1,200);
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al procesar Situacion. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      return v_retorno;
  end fu_act_sit_poliza;

  -- Funcion para la Actualizacion de la Fecha de Entrega de la Póliza --
  function fu_act_ent_poliza( p_codigo       in number,   -- Número de Solicitud en SEBAOT
                              p_fec_entrega  in date      -- Fecha de entrega de la póliza al Cliente.
                             ) return typ_mensajeRespuesta is
    -- Variables --
    v_retorno       typ_mensajeRespuesta := typ_mensajeRespuesta();
    v_nro_error     number;
    v_msj_error     varchar2(200);
    v_codigo        ge_pol_seguros.codigo%type;
    v_fec_entrega   ge_pol_seguros.fec_entrega%type;
    -- Procedimiento para actualizar datos en la tabla GE_POL_SEGUROS --
    procedure lp_act_ge_pol_seguros( p_codigo ge_pol_seguros.codigo%type,           -- Número de Solicitud
                                     p_fec_entrega ge_pol_seguros.fec_entrega%type  -- Fecha de entrega
                                    ) is
    begin
      update ge_pol_seguros
         set fec_entrega = nvl(p_fec_entrega,fec_entrega)
       where codigo = p_codigo;
    end lp_act_ge_pol_seguros;
  begin
    -- Validar que exista una Solicitud con el Número recibido --
    begin
      select a.codigo
        into v_codigo
        from ge_pol_seguros a
       where a.codigo = p_codigo;
    exception
      when no_data_found then
        v_nro_error := 4001;
        v_msj_error := 'Solicitud inexistente.';
        v_retorno.error                := 'S';
        v_retorno.nombreRespuesta      := 'ERROR';
        v_retorno.descripcionRespuesta := substr('Error al procesar la entrega de Poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
        return v_retorno;
    end;
    -- Fecha Entrega --
    if p_fec_entrega is not null then
      v_fec_entrega := p_fec_entrega;
    end if;
    -- Actualizar datos en la Tabla GE_POL_SEGUROS --
    lp_act_ge_pol_seguros(v_codigo, v_fec_entrega);
    commit;
    -- Cargar Retorno para Operación Finalizada --
    v_retorno.error                := 'N';
    v_retorno.nombreRespuesta      := 'OK';
    v_retorno.descripcionRespuesta := 'Transaccion aprobada';
    return v_retorno;
  exception
    when others then
      v_nro_error := 4999;
      v_msj_error := substr(SQLERRM,1,200);
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al procesar la entrega de Poliza. '||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      return v_retorno;
  end fu_act_ent_poliza;
--************ Funcion para realizar el Alta la cuota *******************
function fu_ins_cuota(p_codigo           in number,               -- Numero de Solicitud en SEBAOT
                      p_nro_cuota        in number,               -- Numero de Cuota
                      p_monto            in number,               -- Monto de Cuota
                      p_fec_vencimiento  in date,                 -- Fecha de Vencimiento
                      p_observacion      in varchar2 default null --Observacion
                      ) return typ_mensajeRespuesta is
  -- Variables --
  v_retorno       typ_mensajeRespuesta := typ_mensajeRespuesta();
  rp_gcu          ge_pol_cuotas%rowtype;
  v_cantidad      number(10);
  v_nro_error     number;
  v_msj_error     varchar2(200);
  v_val_fecha     varchar2(10):= nvl(fug_obt_pardinamico('VAL_FEC_SEG'),'N');
  /*********RETORNOS POSIBLES *********************
  1000 - Nro.Solicitud No Recibida.
  1001 - Solicitud Inexistente.
  1002 - Nro.Cuota No Recibida.
  1003 - Nro.Cuota ya Existente.
  1004 - Monto de Cuota debe ser Mayor a Cero.
  1005 - La Fecha de Vencimiento no debe ser Nula y Debe ser Mayor o Igual a Hoy.
  1999 - Otro Error
  ************************************************
  */

   --***** Procedimiento para insertar datos en la tabla GE_POL_CUOTAS *****
   procedure lp_ins_ge_pol_cuotas(rp_gcu ge_pol_cuotas%rowtype) is
   begin
      insert into ge_pol_cuotas( codigo, nro_cuota, Fec_Vencimiento,Monto,observacion,estado)
      values( rp_gcu.codigo, rp_gcu.nro_cuota, rp_gcu.fec_vencimiento, rp_gcu.monto,
              rp_gcu.observacion,'I' );
   end lp_ins_ge_pol_cuotas;
   --***** Procedimiento para insertar datos del error en la tabla ge_log_polizas *****
   procedure lp_ins_error_cuo(p_codigo varchar2, p_observacion varchar2) is
     v_existe number;
   begin
      select count(*)
        into v_existe
        from ge_log_polizas a
       where a.nro_documento = p_codigo;
      if v_existe >= 1 then
        delete ge_log_polizas a where a.nro_documento = to_char(p_codigo);
        insert into ge_log_polizas(nro_documento, observacion)
        values(p_codigo, p_observacion);
      else
        insert into ge_log_polizas(nro_documento, observacion)
        values(p_codigo, p_observacion);
      end if;
      commit;
   end lp_ins_error_cuo;
  begin
   --*************************PROCESO PRINCIPAL ******************
   --***** Validar que exista la Solicitud en ge_pol_seguros *****
   if nvl(p_codigo,0)=0 then
      v_nro_error := 1000;
      v_msj_error := 'Nro.Solicitud No Recibida.';
      v_retorno.error := 'S';
      v_retorno.nombreRespuesta := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al buscar solicitud-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      lp_ins_error_cuo(p_codigo, v_retorno.descripcionRespuesta);
      return v_retorno;
   else
       begin
          select a.codigo
            into rp_gcu.codigo
            from ge_pol_seguros a
           where a.codigo = p_codigo;
        exception
          when no_data_found then
              v_nro_error := 1001;
              v_msj_error := 'Solicitud Inexistente.';
              v_retorno.error := 'S';
              v_retorno.nombreRespuesta := 'ERROR';
              v_retorno.descripcionRespuesta := substr('Error al buscar solicitud-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
              lp_ins_error_cuo(p_codigo, v_retorno.descripcionRespuesta);
              return v_retorno;
          when others then
              v_retorno.error := 'N';
        end;
   
    end if;
    --********************************
    --***** Validar Nro de Cuota *****
    if nvl(p_nro_cuota,-1) < 0  then
       v_nro_error := 1002;
       v_msj_error := 'Nro.Cuota No Recibida.';
       v_retorno.error := 'S';
       v_retorno.nombreRespuesta := 'ERROR';
       v_retorno.descripcionRespuesta := substr('Error al validar Nro.Cuota-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
       lp_ins_error_cuo(p_codigo, v_retorno.descripcionRespuesta);
       return v_retorno;
    else
         rp_gcu.codigo    := nvl(p_codigo,0);
         rp_gcu.nro_cuota := nvl(p_nro_cuota,0);
          v_cantidad:=0;
          begin
            select count(*)
              into v_cantidad
              from ge_pol_cuotas a
             where a.codigo = p_codigo
                 and a.nro_cuota= p_nro_cuota;
          exception
            when no_data_found then
              null;
            when others then
              null;
          end;

          if nvl(v_cantidad,0)> 0 then
             v_nro_error := 1003;
             v_msj_error := 'Nro.Cuota ya Existente.';
             v_retorno.error := 'S';
             v_retorno.nombreRespuesta := 'ERROR';
             v_retorno.descripcionRespuesta := substr('Error al validar Nro.Cuota-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
             lp_ins_error_cuo(p_codigo, v_retorno.descripcionRespuesta);
             return v_retorno;
          end if;
     end if;
     --********************************
     --***** Validar Monto ************
     if nvl(p_monto,0) <= 0  then
       v_nro_error := 1004;
       v_msj_error := 'Monto de Cuota debe ser Mayor a Cero.';
       v_retorno.error := 'S';
       v_retorno.nombreRespuesta := 'ERROR';
       v_retorno.descripcionRespuesta := substr('Error al validar Monto-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
       lp_ins_error_cuo(p_codigo, v_retorno.descripcionRespuesta);
       return v_retorno;
     else
        rp_gcu.monto := p_monto;
     end if;
     --********************************
     --***** Validar Fec_Vencimiento **
    if p_fec_vencimiento is null or trunc(p_fec_vencimiento) <= trunc(pag_cal.FU_OBT_FEC_ACTUAL(1))   
       and nvl(v_val_fecha,'N')= 'S' then
         v_nro_error := 1005;
         v_msj_error := 'La Fecha de Vencimiento no debe ser Nula y Debe ser Mayor o Igual a Hoy.';
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta := 'ERROR';
         v_retorno.descripcionRespuesta := substr('Error al validar Fec.Vto.-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
         lp_ins_error_cuo(p_codigo, v_retorno.descripcionRespuesta);
         return v_retorno;
    else
       rp_gcu.fec_vencimiento := trunc(p_fec_vencimiento);
    end if;
    
    
    --********************************
    rp_gcu.observacion:= p_observacion;
    --borra de la tabla si esta todo ok
    delete ge_log_polizas a where a.nro_documento = to_char(p_codigo);
    -- Insertar datos en la Tabla GE_POL_CUOTAS --
    lp_ins_ge_pol_cuotas(rp_gcu);
    commit;
    -- Cargar Retorno para Operacion Finalizada --
    v_retorno.error                := 'N';
    v_retorno.nombreRespuesta      := 'OK';
    v_retorno.descripcionRespuesta := 'Transaccion aprobada';
    return v_retorno;
exception
    when others then
      v_nro_error := 1999;
      v_msj_error := substr(SQLERRM,1,200);
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al ingresar Nro.Cuota '||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      lp_ins_error_cuo(p_codigo, v_retorno.descripcionRespuesta);
      return v_retorno;
end fu_ins_cuota;
--************ Funcion para realizar el Alta del Cobro *******************
function fu_ins_cobro(p_codigo           in number,               -- Numero de Solicitud en SEBAOT
                      p_nro_cuota        in number,               -- Numero de Cuota
                      p_nro_pago         in number,               -- Numero de Pago(1,2,3...)
                      p_fec_cobro        in date,                 -- Fecha de Cobro
                      p_importe          in number,               -- Monto de Cuota
                      p_tip_cobro        in number,               -- Tipo de Cobro(O-Normal/1-Amoritizacion/2-Credito Prima/3-Cred. de Iva)
                      p_nro_recibo       in number,               -- Nro.de Recibo
                      p_observacion      in varchar2 default null -- Observacion
                      ) return typ_mensajeRespuesta is
  -- Variables --
  v_retorno       typ_mensajeRespuesta := typ_mensajeRespuesta();
  rp_gco          ge_pol_cobros%rowtype;
  v_cantidad      number(10);
  v_nro_error     number;
  v_msj_error     varchar2(200);
  v_estado        varchar2(1):=0;
  v_tot_cobro     number(18,2);
  v_mto_cuota     number(18,2);
  v_val_fecha     varchar2(10):= nvl(fug_obt_pardinamico('VAL_FEC_SEG'),'N');
  /*********RETORNOS POSIBLES *********************
  1000 - Nro.Solicitud No Recibida.
  1001 - Solicitud Inexistente.
  1002 - La Solicitud No se encuentra en Estado Emitida.
  1003 - Nro.Cuota No Recibida.
  1004 - Nro.Cuota No Existe.
  1005 - El Nro de Cuota ya fue Migrado, con el mismo Nro. de Pago.
  1006 - Importe de Cobro debe ser Mayor a Cero.
  1007 - Importe de Cobro debe ser Menor a Importe de la Cuota.
  1008 - La Fecha de Cobro No debe ser Nula y debe ser Menor o Igual a Hoy.
  1009 - Tipo de Cobro No Recibido.
  1010 - Tipo de Cobro No Valido.
  1011 - Nro. de Recibo No Recibido.
  1012 - No se pudo actualizar el estado de cuota (Para Pago Parcial)
  1013 - No se pudo actualizar el estado de cuota (Para Pago Total)
  1999 - Otro Error
  ************************************************
  */
   --***** Procedimiento para insertar datos en la tabla GE_POL_COBROS *****
   procedure lp_ins_ge_pol_cobros(rp_gco ge_pol_cobros%rowtype) is
   begin
      insert into ge_pol_cobros( codigo, nro_cuota, nro_pago, Fec_cobro,importe,tip_cobro,
                                 nro_recibo,observacion)
      values( rp_gco.codigo, rp_gco.nro_cuota,rp_gco.nro_pago,rp_gco.fec_cobro, rp_gco.importe,rp_gco.tip_cobro,
                                 rp_gco.nro_recibo,rp_gco.observacion );
   end lp_ins_ge_pol_cobros;
   --***** Procedimiento para insertar datos del error en la tabla ge_log_polizas *****
   procedure lp_ins_error_cob(p_codigo varchar2, p_observacion varchar2) is
     v_existe number;
   begin
      select count(*)
        into v_existe
        from ge_log_polizas a
       where a.nro_documento = p_codigo;
      if v_existe >= 1 then
        delete ge_log_polizas a where a.nro_documento = to_char(p_codigo);
        insert into ge_log_polizas(nro_documento, observacion)
        values(p_codigo, p_observacion);
      else
        insert into ge_log_polizas(nro_documento, observacion)
        values(p_codigo, p_observacion);
      end if;
      commit;
   end lp_ins_error_cob;
  --*************************PROCESO PRINCIPAL ******************************************
   begin
   --***** Validar que exista la Solicitud en ge_pol_seguros *****
   if nvl(p_codigo,0)=0 then
      v_nro_error := 1000;
      v_msj_error := 'Nro.Solicitud No Recibida.';
      v_retorno.error := 'S';
      v_retorno.nombreRespuesta := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al buscar Solicitud-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
      return v_retorno;
   else
       begin
          select a.codigo,a.estado
            into rp_gco.codigo,v_estado
            from ge_pol_seguros a
           where a.codigo = p_codigo;
        exception
          when no_data_found then
              v_nro_error := 1001;
              v_msj_error := 'Solicitud Inexistente.';
              v_retorno.error := 'S';
              v_retorno.nombreRespuesta := 'ERROR';
              v_retorno.descripcionRespuesta := substr('Error al buscar solicitud-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
              lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
              return v_retorno;
          when others then
              v_retorno.error := 'N';
        end;
       if  nvl(v_val_fecha,'N')= 'S'  THEN --Solo despues de migrar se valida
            if NVL(v_estado,'1') <> '2' THEN
                v_nro_error := 1002;
                v_msj_error := 'La Solicitud No se encuentra en Estado Emitida.';
                v_retorno.error := 'S';
                v_retorno.nombreRespuesta := 'ERROR';
                v_retorno.descripcionRespuesta := substr('Error al buscar solicitud-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
                lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
                return v_retorno;
           end if;
       end if;

    end if;
    rp_gco.codigo := p_codigo;
    --********************************
    --***** Validar Nro de Cuota *****
    --Puede ser Cero
    if nvl(p_nro_cuota,-1) < 0  then
       v_nro_error := 1003;
       v_msj_error := 'Nro.Cuota No Recibida.';
       v_retorno.error := 'S';
       v_retorno.nombreRespuesta := 'ERROR';
       v_retorno.descripcionRespuesta := substr('Error al validar Nro.Cuota-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
       lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
       return v_retorno;
    else
         --Buscamos que exista en la tabla de cuotas
          rp_gco.nro_cuota := p_nro_cuota;
          v_cantidad:=0;
          begin
            select count(*)
              into v_cantidad
              from ge_pol_cuotas a
             where a.codigo = p_codigo
                 and a.nro_cuota= p_nro_cuota;
          exception
            when no_data_found then
               null;
            when others then
               null;
          end;
          --Ya debe existir en la tabla de cuotas
          if nvl(v_cantidad,0)= 0 then
                 v_nro_error := 1004;
                 v_msj_error := 'Nro.Cuota No Existe.';
                 v_retorno.error := 'S';
                 v_retorno.nombreRespuesta := 'ERROR';
                 v_retorno.descripcionRespuesta := substr('Error al validar Nro.Cuota-'||'Solicitud Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
                 lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
                 return v_retorno;
          end if;
          --Buscamos que ya no haya sido insertado en la tabla de cobros
          v_cantidad:=0;
          begin
            select count(*)
              into v_cantidad
              from ge_pol_cobros a
             where a.codigo = p_codigo
                 and a.nro_cuota= p_nro_cuota
                 and a.nro_pago= p_nro_pago;
          exception
            when no_data_found then
              v_cantidad:=0;
             when others then
               null;
          end;
          if nvl(v_cantidad,0) >=1 then
                  v_nro_error := 1005;
                 v_msj_error := 'El Nro de Cuota ya fue Migrado, con el mismo Nro. de Pago.';
                 v_retorno.error := 'S';
                 v_retorno.nombreRespuesta := 'ERROR';
                 v_retorno.descripcionRespuesta := substr('Error al validar Nro.Cobro-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
                 lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
                 return v_retorno;
          end if;

     end if;
    --********************************
    --****** Validar Importe *********
     if nvl(p_importe,-1) < 0  then
       v_nro_error := 1006;
       v_msj_error := 'Importe de Cobro debe ser Mayor a Cero.';
       v_retorno.error := 'S';
       v_retorno.nombreRespuesta := 'ERROR';
       v_retorno.descripcionRespuesta := substr('Error al validar Monto-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
       lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
       return v_retorno;
     else
        --Buscamos que no supere el monto de Cuota Definido en la tabla de Cuotas
        rp_gco.importe := p_importe;
        v_tot_cobro:=0;
        v_mto_cuota:=0;
         --Obtenemos el total de la cuota
         begin
            select nvl(a.monto,0)
              into  v_mto_cuota
              from ge_pol_cuotas a
             where a.codigo = p_codigo
                 and a.nro_cuota= p_nro_cuota;
          exception
            when no_data_found then
               v_mto_cuota:=0;
            when others then
               v_mto_cuota:=0;
          end;
          --Obtenemos lo que ya se cobro de la cuota
           begin
            select nvl(sum(a.importe),0)
              into  v_tot_cobro
              from ge_pol_cobros a
             where a.codigo = p_codigo
                 and a.nro_cuota= p_nro_cuota;
          exception
            when no_data_found then
               v_tot_cobro:=0;
            when others then
               v_tot_cobro:=0;
          end;
          --El monto de lo cobrado no puede ser mayor al monto de la cuota
          if nvl(v_mto_cuota,0) < (nvl(v_tot_cobro,0) + nvl(p_importe,0)) then
               v_nro_error := 1007;
               v_msj_error := 'Importe de Cobro debe ser Menor a Importe de la Cuota.';
               v_retorno.error := 'S';
               v_retorno.nombreRespuesta := 'ERROR';
               v_retorno.descripcionRespuesta := substr('Error al validar Monto Cobrado-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
               lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
               return v_retorno;
          end if;
     end if;
    --********************************
    --***** Validar Fec_Cobro ********
    if ((p_fec_cobro is null or trunc(p_fec_cobro) > trunc(pag_cal.FU_OBT_FEC_ACTUAL(1))) 
        and (nvl(v_val_fecha,'N')= 'S')) then
         v_nro_error := 1008;
         v_msj_error := 'La Fecha de Cobro no debe ser Nula y debe ser Menor o Igual a Hoy.';
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta := 'ERROR';
         v_retorno.descripcionRespuesta := substr('Error al validar Fec.Cobro-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
         lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
         return v_retorno;
     else
       rp_gco.fec_cobro := trunc(p_fec_cobro);
     end if;
     --********************************
     --****** Validar Tipo de Cobro ***
     --0 = Normal/ 1 = Amortizaci?n/ 2 = Cr?dito de Prima de Anulaci?n/ 3 = Cr?dito de Iva de Anulaci?n.
     if p_tip_cobro is null then
         v_nro_error := 1009;
         v_msj_error := 'Tipo de Cobro No Recibido.';
         v_retorno.error := 'S';
         v_retorno.nombreRespuesta := 'ERROR';
         v_retorno.descripcionRespuesta := substr('Error al validar Tipo De Cobro-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
         lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
         return v_retorno;
     else
       rp_gco.tip_cobro := p_tip_cobro;
       if p_tip_cobro not in (0,1,2,3) then
          v_nro_error := 1010;
          v_msj_error := 'Tipo de Cobro No Valido.';
          v_retorno.error := 'S';
          v_retorno.nombreRespuesta := 'ERROR';
          v_retorno.descripcionRespuesta := substr('Error al validar Tipo De Cobro-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
          lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
          return v_retorno;
       end if;
     end if;
     --********************************
     --****** Validar Nro.Recibo ******
     --Se puede recibir cero
     /*if nvl(p_nro_recibo,-1) < 0  then
       v_nro_error := 1011;
       v_msj_error := 'Nro. de Recibo No Recibido.';
       v_retorno.error := 'S';
       v_retorno.nombreRespuesta := 'ERROR';
       v_retorno.descripcionRespuesta := substr('Error al validar Monto-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
       lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
       return v_retorno;
     end if;*/
     --********************************
    rp_gco.observacion:= p_observacion;
    rp_gco.Nro_Pago := p_nro_pago;
    rp_gco.Nro_recibo := p_nro_recibo;
    --borra de la tabla si esta todo ok
    delete ge_log_polizas a where a.nro_documento = to_char(p_codigo);
    -- Insertar datos en la Tabla GE_POL_COBROS --
    lp_ins_ge_pol_cobros(rp_gco);
    --Luego de Insertar el Cobro, actualizamos la cuota
    --Si el monto de la cuota el igual a lo ya Pagado + Lo que se esta pagando
    if nvl(v_mto_cuota,0) = (nvl(v_tot_cobro,0) + nvl(p_importe,0)) then
      --Actualizamos el campo estado a T (Pago Total)
          begin
             update ge_pol_cuotas a
                set a.estado='T'
              where a.codigo = p_codigo
                 and a.nro_cuota= p_nro_cuota;
          exception
             when others then
                v_nro_error := 1012;
                v_retorno.error := 'S';
                v_retorno.nombreRespuesta := 'ERROR';
                v_msj_error := 'No se pudo actualizar el estado de cuota';
                return v_retorno;
          end;
     elsif  nvl(v_mto_cuota,0) > (nvl(v_tot_cobro,0) + nvl(p_importe,0)) then
         begin
            update ge_pol_cuotas a
                set a.estado='P'
              where a.codigo = p_codigo
                 and a.nro_cuota= p_nro_cuota;
          exception
             when others then
                v_nro_error := 1013;
                v_retorno.error := 'S';
                v_retorno.nombreRespuesta := 'ERROR';
                v_msj_error := 'No se pudo actualizar el estado de cuota';
                return v_retorno;
          end;
      end if;
    --Si lleg? hasta aqui no hubo errores, se comitea
    commit;
    -- Cargar Retorno para Operacion Finalizada --
    v_retorno.error                := 'N';
    v_retorno.nombreRespuesta      := 'OK';
    v_retorno.descripcionRespuesta := 'Transaccion aprobada';
    return v_retorno;
exception
    when others then
      v_nro_error := 1999;
      v_msj_error := substr(SQLERRM,1,200);
      v_retorno.error                := 'S';
      v_retorno.nombreRespuesta      := 'ERROR';
      v_retorno.descripcionRespuesta := substr('Error al ingresar Cobro-'||'Sol.Nro.: '||p_codigo||'. ERROR: '||v_nro_error||' - '||v_msj_error,1,200);
      lp_ins_error_cob(p_codigo, v_retorno.descripcionRespuesta);
      return v_retorno;
end fu_ins_cobro;

--
begin
   pre_cam_for_numerico('.,');
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 9; --Modulo caja
end pag_pol;
/

