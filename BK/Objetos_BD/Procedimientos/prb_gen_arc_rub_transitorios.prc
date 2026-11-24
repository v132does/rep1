create or replace procedure it.prb_gen_arc_rub_transitorios is

  v_cod_error       number(6);
  v_men_error       varchar2(4000);
  v_pro_correcto    number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),0);
  v_err_sql         number := nvl(fug_obt_pardinamico('COD_ERR_SQL'),999);
  v_lugar           varchar2(10);
  p_date            varchar2(35);
  v_fecha_anterior  date;
  procedure lp_inv_gen_arc_rub_tra_ws ( p_content   in varchar2,
                                                p_cod_error out number,
                                                p_men_error out varchar2) is
   -- invoca al web service que genera los archivos de rubros transitorios
   v_req             utl_http.req;
   v_res             utl_http.resp;
   v_cod_err_ws      number(6);
   v_error           exception;
   v_can_max_espera  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_MAX_ESPERA');
   v_url             varchar2(4000) := fug_obt_pardinamico('WS_GEN_ARC_RUB_TRANSITORIO');
   v_metodo          varchar2(6) := 'POST';   -- es el tipo de metodo PUT, POST, GET
   v_cod_asincrono   number := 202; -- codigo de exito para invocacion asincrona del web service

  begin
   v_lugar := '2.1';
   --seteamos el tiempo maximo de espera a la respuesta del web service
   UTL_HTTP.SET_TRANSFER_TIMEOUT (to_number(v_can_max_espera));
   p_cod_error := v_pro_correcto;
   p_men_error := 'Operacion Exitosa.';
   --solicitud ws
   v_lugar := '2.2';
   v_req := utl_http.begin_request(v_url||p_content, v_metodo,'HTTP/1.1');
   v_lugar := '2.3';

   /*El contenido que enviamos es XML: */
   utl_http.set_header(v_req, 'content-type', 'application/x-www-form-urlencoded');
   utl_http.set_header(v_req, 'Connection', 'close');

   /*Obtenemos la respuesta */
   v_lugar := '2.4';
   v_res := utl_http.get_response(v_req);

   /*Obtiene el codigo de respuesta */
   v_lugar := '2.5';
   v_cod_err_ws := v_res.status_code;

   /*Finalizamos la conexion HTTP */
   v_lugar := '2.8';
   utl_http.end_response(v_res);

   /*Validamos el codigo de error */
   if v_cod_err_ws != v_cod_asincrono then
    v_lugar := '2.10';
    p_cod_error := v_err_sql;
    p_men_error := 'Error en la invocacion al web service.';
   end if;

  exception
   when others then
    p_cod_error := v_err_sql;
    p_men_error := substr('Lugar: '||v_lugar||' - Error en LP_INV_GEN_ARC_RUB_TRA_WEBSERVICE: '||utl_http.get_detailed_sqlerrm,1,4000);
    utl_http.end_response(v_res);
  end;

  begin
   /*Programa principal */
   /*Invoca al web service de generacion de archivos de rubros transitotrios de forma asincrona */

   /*asigna la fecha para el parametro del web service */
   v_lugar := '1';
   v_fecha_anterior := pag_cal.fu_obt_fec_anterior(2); --fecha anterior del modulo contable
   p_date := '?date='||to_char(trunc(v_fecha_anterior),'ddmmyyyy');


   v_lugar := '2';
   /*invocamos al programa que se conecta al web service */
   lp_inv_gen_arc_rub_tra_ws(p_date, v_cod_error, v_men_error);

   /*Validamos que no tenga error */
   if v_cod_error != v_pro_correcto then
     v_lugar := '3';
     RAISE_APPLICATION_ERROR(-20000, 'Error en lugar: '||v_lugar||' - '||v_men_error);
   end if;

  exception
    when others then
       RAISE_APPLICATION_ERROR(-20000, 'Error en lugar: '||v_lugar||' - '||sqlerrm);
  end;
/

