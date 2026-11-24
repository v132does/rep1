create or replace procedure it.prg_act_cli_bcp is
 --consulta datos tabla temporal
 cursor c_dat is
  select a.nro_documento, a.tip_documento,a.dat_respuesta
    from ge_clientes_bcp_tmp a;
  -- parseamos los campos y obtenemos los datos
 cursor cli_bcp (p_tip_documento varchar2 ,p_nro_documento varchar2) is
      select b.cod_resultado,b.resultado,b.periodo,b.tip_documento,b.nro_documento,b.nro_gpv,b.nombres,b.apellidos,b.fec_nacimiento,
             b.tip_vinculo,b.tip_operacion,b.desc_operacion,b.cod_cta_sal_capital,b.cod_activ_destino,
             b.region,b.cod_moneda, b.dias_atraso,b.deuda_activa,b.deuda_vendida,b.deuda_incobrable,
             b.deuda_fideicomiso,b.monto_contingencia,b.monto_prevision,b.clasif_sistema
      from ge_clientes_bcp_tmp a,
           json_table(a.dat_respuesta, '$.body.resultado[*]'
                            columns(cod_resultado varchar2(3) path '$.codigoResultado',
                                    resultado varchar2(25) path '$.descripcionResultado',
                                    periodo varchar2(6) path '$.periodo',
                                    tip_documento varchar2(32) path '$.codTipoDocumento',
                                    nro_documento varchar2(15) path '$.numeroDocumento',
                                    nro_gpv varchar2(40) path '$.nroGpv',
                                    nombres varchar2(255) path '$.nombres',
                                    apellidos varchar2(60) path '$.apellidos',
                                    fec_nacimiento varchar2(8) path '$.fechaNacimiento',
                                    tip_vinculo varchar2(100) path '$.tipoVinculo',
                                    tip_operacion varchar2(3) path '$.tipoOperacion',
                                    desc_operacion varchar2(100) path '$.desOperacion',
                                    cod_cta_sal_capital varchar2(18) path '$.codCuentaSaldoCapital',
                                    cod_activ_destino varchar2(6) path '$.codActividadDestino',
                                    region varchar2(100) path '$.region',
                                    cod_moneda varchar2(3) path '$.codigoMoneda',
                                    dias_atraso varchar2(5) path '$.diasAtraso',
                                    deuda_activa varchar2(18) path '$.deudaActiva',
                                    deuda_vendida varchar2(18) path '$.deudaVendida',
                                    deuda_incobrable varchar2(18) path '$.deudaIncobrable',
                                    deuda_fideicomiso varchar2(18) path '$.deudaFideicomiso',
                                    monto_contingencia varchar2(18) path '$.montoContingencia',
                                    monto_prevision varchar2(18) path '$.montoPrevision',
                                    clasif_sistema varchar2(2) path '$.clasificacionSistema' )) as b
                 where a.tip_documento = p_tip_documento
                 and a.nro_documento = p_nro_documento;

  -- depositos
  cursor cli_bcp_depositos (p_tip_documento varchar2 ,p_nro_documento varchar2) is
      select b.cod_resultado,b.resultado,b.periodo,b.tip_documento,b.nro_documento,b.nombres,b.apellidos,b.fec_nacimiento,
             b.tot_depositos
      from ge_cli_bcp_depositos a,
           json_table(a.dat_respuesta, '$.body.resultado[*]'
                            columns(cod_resultado varchar2(3) path '$.codigoResultado',
                                    resultado varchar2(25) path '$.descripcionResultado',
                                    periodo varchar2(6) path '$.periodo',
                                    tip_documento varchar2(32) path '$.codTipoDocumento',
                                    nro_documento varchar2(15) path '$.numeroDocumento',
                                    nro_gpv varchar2(40) path '$.nroGpv',
                                    nombres varchar2(255) path '$.nombres',
                                    apellidos varchar2(60) path '$.apellidos',
                                    fec_nacimiento varchar2(8) path '$.fechaNacimiento',
                                    tot_depositos number path '$.totalDepositosSistema')) as b
                 where a.tip_documento = p_tip_documento
                 and a.nro_documento = p_nro_documento;
   --definicion de variables
  v_consulta  varchar2(200);
  v_url       varchar2(4000) := fug_obt_pardinamico('WS_URL_BCP');
  v_url_deposito varchar2(4000) := fug_obt_pardinamico('WS_URL_BCP_DEP');
  v_men_error    varchar2(4000);
  v_cod_err_ws   varchar2(10);
  v_fec_actual   date;
  v_periodo      varchar2(6);
   v_nom_programa   varchar2(50) := 'PRG_ACT_CLI_BCP';
   v_lugar      varchar2(10);
   v_error exception;
   --------------------------------------------------------------------
   -- llama al web service de acuerdo a la accion solicitada
  procedure pr_ws_conector(p_content     in varchar2, -- estructura jason
                           p_url         in varchar2, -- url para utilizar en la consulta
                           p_accion      in varchar2, -- si es cambio de estado o alta
                           p_metodo      in varchar2, -- es el tipo de metodo PUT, POST, GET
                           p_cod_error   out number,
                           p_men_error   out varchar2) is

    v_req        utl_http.req;
    v_res        utl_http.resp;
    v_buffer     varchar2(4000);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);

    v_can_max_espera ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_MAX_ESPERABCP');
  begin
    --seteamos el tiempo maximo de espera a la respuesta del web service - inicial 60seg.
    UTL_HTTP.SET_TRANSFER_TIMEOUT(to_number(v_can_max_espera));
    --solicitud ws
    if p_accion = 'M' then
      --modificacion de estado 'PUT'
      v_lugar := '01';
      v_req   := utl_http.begin_request(p_url, p_metodo, ' HTTP/1.1');
    elsif p_accion = 'A' then
      --alta de cuenta en global y alta de tarjeta 'POST'
      v_lugar := '02';
      v_req   := utl_http.begin_request(p_url, p_metodo, ' HTTP/1.1');
    end if;
    v_lugar := '03';
    if p_content is not null then
      utl_http.set_header(v_req, 'content-type', 'application/json');
      utl_http.set_header(v_req, 'Content-Length', length(p_content));
      utl_http.write_text(v_req, p_content);
    end if;
    --respuesta ws
    v_lugar := '04';
    v_res   := utl_http.get_response(v_req);
    ---obtiene el codigo de respuesta
    v_lugar      := '05';
    v_cod_err_ws := v_res.status_code;
    --obtiene los datos del WS
    v_lugar := '06';
    utl_http.read_line(v_res, v_buffer);
    --se guarda la repuesta obtenida
    v_lugar     := '07';
    v_men_error := v_buffer;
    v_lugar     := '08';
    utl_http.end_response(v_res);
    v_lugar     := '09';
    p_men_error := v_men_error;

    if v_cod_err_ws != '01' then
      p_cod_error := v_cod_err_ws;
      prg_ins_log_programas(v_nom_programa,
                            substr('1) Lugar: ' || v_lugar || ' - ' ||
                                   v_cod_err_ws || ' - ' || p_men_error,
                                   1,
                                   4000));
    end if;

  exception
    when others then
      p_men_error := substr('Lugar: ' || v_lugar ||
                            ' - Url: ' || p_url ||
                            ' - WS_Err_Desc : ' || utl_http.get_detailed_sqlerrm ||
                            ' - Error en PR_WS_CONECTOR: ' || sqlerrm,
                            1,
                            4000);

      utl_http.end_response(v_res);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error);
  end;
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
  --v_periodo := to_char(add_months(v_fec_actual,-3),'yyyymm');
  v_periodo := fug_obt_pardinamico('PER_CON_BCP');
  for k in c_dat loop
    --Arma el mensaje o consulta a enviar
    v_consulta := '{'||'"codTipoDocumento":'||'"'||k.tip_documento||'"'||','||
                    '"numeroDocumento":'||'"'||k.nro_documento||'"'||','||
                    '"periodo":'||'"'||v_periodo||'"'||'}';

   --conecta con el servicio/el servicio devuelve una respuesta en v_men_error
    pr_ws_conector(v_consulta, v_url, 'A', 'POST', v_cod_err_ws, v_men_error);
    --obtengo la fecha actual del modulo
    v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
    -- Actualiza la respuesta
    begin
      update ge_clientes_bcp_tmp a
         set a.dat_respuesta = v_men_error
       where a.tip_documento = k.tip_documento
         and a.nro_documento = k.nro_documento;
    end;
    if nvl(v_cod_err_ws,'200') = '200' then
      -- Si ya existe para la fecha se elimina para volver a insertar.
      begin
       delete ge_clientes_bcp
        where tip_documento = k.tip_documento
          and nro_documento = k.nro_documento
          and periodo = v_periodo;
      end;
      for e in cli_bcp (k.tip_documento,k.nro_documento) loop
        if e.cod_resultado = '01' then -- ok
          begin
            --insertar tabla luego de parsear datos
            insert into  ge_clientes_bcp b
                 (b.cod_resultado,b.resultado,b.periodo,b.tip_documento,b.nro_documento,
                  b.nro_gpv,b.nombres,b.apellidos,b.fec_nacimiento,
                  b.tip_vinculo,b.tip_operacion,b.desc_operacion,b.cod_cta_sal_capital,b.cod_activ_destino,
                  b.region,b.cod_moneda, b.dias_atraso,b.deuda_activa,b.deuda_vendida,b.deuda_incobrable,
                  b.deuda_fideicomiso,b.monto_contingencia,b.monto_prevision,b.clasif_sistema,
                  b.dat_respuesta,b.fec_proceso)
             values  ( e.cod_resultado,e.resultado,e.periodo,e.tip_documento,e.nro_documento,
              e.nro_gpv,e.nombres,e.apellidos,e.fec_nacimiento,
              e.tip_vinculo,e.tip_operacion,  e.desc_operacion,e.cod_cta_sal_capital,e.cod_activ_destino,
              e.region,e.cod_moneda,e.dias_atraso,e.deuda_activa,e.deuda_vendida,e.deuda_incobrable,
              e.deuda_fideicomiso,e.monto_contingencia,e.monto_prevision,e.clasif_sistema,
              v_men_error,v_fec_actual);
          exception
            when others then
              v_men_error := '01 Al insertar en ge_clientes_bcp #'||sqlerrm;
              prg_ins_log_programas(v_nom_programa, substr('Error: '||v_men_error,1,4000));
          end;
        elsif e.cod_resultado <> '01' then --lista de errores (00,02,03)
          begin
            insert into ge_clientes_bcp a (a.cod_resultado,a.resultado,a.tip_documento,a.nro_documento,a.dat_respuesta,a.fec_proceso)
            values (e.cod_resultado,e.resultado,k.tip_documento,k.nro_documento,v_men_error,v_fec_actual);
          exception
            when others then
              v_men_error := '02 Al insertar en ge_clientes_bcp #'||sqlerrm;
              prg_ins_log_programas(v_nom_programa, substr('Error: '||v_men_error,1,4000));
          end;
        end if;
      end loop;
   else
     v_men_error := '03 Error al llamar servicio status='||v_cod_err_ws||' Consolidado. Tipo/Nro.Doc: '||k.tip_documento||'/'||k.nro_documento;
     prg_ins_log_programas(v_nom_programa, substr('Error: '||v_men_error,1,4000));
   end if;
   -- Depositos
   pr_ws_conector(v_consulta, v_url_deposito, 'A', 'POST', v_cod_err_ws, v_men_error);
   begin
     delete ge_cli_bcp_depositos a
      where a.tip_documento = k.tip_documento
        and a.nro_documento = k.nro_documento
        and a.periodo = v_periodo;
   end;
   begin
     delete ge_cli_bcp_depositos a
      where a.tip_documento = k.tip_documento
        and a.nro_documento = k.nro_documento
        and a.fec_proceso = v_fec_actual
        and a.periodo is null;
   end;
   begin
     insert into ge_cli_bcp_depositos(tip_documento,nro_documento,fec_proceso,dat_respuesta)
     values(k.tip_documento, k.nro_documento, v_fec_actual, v_men_error);
   exception
     when others then
       v_men_error := '01 Al insertar respuesta en ge_cli_bcp_depositos #'||sqlerrm;
       prg_ins_log_programas(v_nom_programa, substr('Error: '||v_men_error,1,4000));
   end;
   if nvl(v_cod_err_ws,200) = '200' then
     for d in cli_bcp_depositos(k.tip_documento,k.nro_documento) loop
       if d.cod_resultado = '01' then
         begin
           update ge_cli_bcp_depositos a
           set a.cod_resultado = d.cod_resultado,
               a.resultado = d.resultado,
               a.periodo = d.periodo,
               a.nombres = d.nombres,
               a.apellidos = d.apellidos,
               a.fec_nacimiento = d.fec_nacimiento,
               a.tot_depositos = d.tot_depositos
           where a.tip_documento = d.tip_documento
             and a.nro_documento = d.nro_documento
             and a.fec_proceso = v_fec_actual;
           if sql%notfound then
             begin
               insert into ge_cli_bcp_depositos(cod_resultado,
                                                resultado,
                                                periodo,
                                                tip_documento,
                                                nro_documento,
                                                nombres,
                                                apellidos,
                                                fec_nacimiento,
                                                tot_depositos,
                                                fec_proceso)
               values(d.cod_resultado, d.resultado, d.periodo, d.tip_documento, d.nro_documento, d.nombres,
                      d.apellidos, d.fec_nacimiento, d.tot_depositos, v_fec_actual);
           exception
           when others then
             v_men_error := '01 Al insertar ge_cli_bcp_depositos #'||sqlerrm;
             prg_ins_log_programas(v_nom_programa, substr('Error: '||v_men_error,1,4000));
           end;
           end if;
         exception
           when others then
             v_men_error := '02 Al modificar ge_cli_bcp_depositos #'||sqlerrm;
             prg_ins_log_programas(v_nom_programa, substr('Error: '||v_men_error,1,4000));
         end;
       else
         begin
           update ge_cli_bcp_depositos a
           set a.cod_resultado = d.cod_resultado,
               a.resultado = d.resultado
           where a.tip_documento = k.tip_documento
             and a.nro_documento = k.nro_documento
             and a.fec_proceso = v_fec_actual;
         end;
       end if;
       commit;
     end loop;
   else
     v_men_error := '03 Error al llamar servicio status='||v_cod_err_ws||' Depósitos. Tipo/Nro.Doc: '||k.tip_documento||'/'||k.nro_documento;
     prg_ins_log_programas(v_nom_programa, substr('Error: '||v_men_error,1,4000));
   end if;
  end loop;
exception
    when v_error then
      prg_ins_log_programas(v_nom_programa, substr('Lugar: '||v_lugar||' '||v_men_error,1,4000));
    when others then
      prg_ins_log_programas(v_nom_programa, substr('Lugar: '||v_lugar||' - Error:'||v_men_error||' # '||sqlerrm,1,4000));
end;
/
