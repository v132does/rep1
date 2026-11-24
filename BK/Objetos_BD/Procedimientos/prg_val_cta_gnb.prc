create or replace procedure it.prg_val_cta_gnb(
p_nro_cuenta in varchar2,                  -- nro de cuenta
p_nro_documento in varchar2 default null,  -- nro documento
--Retorno
p_resultado out varchar2,  --S/N
p_cod_moneda out varchar2,
p_cod_modulo out varchar2, --3/4
p_nom_cliente out varchar2,
p_cod_error  out varchar2 
)
is
/**********************************************
Proceso para Validar que cuenta exista en GNB
Solo para Cta.Cte y Caja de Ahorro
moneda: PYG => GS
TipoCta: CC => 4 sino 3
**********************************************/

result typ_postrespuesta;
p_headers typ_listaetiquetavalor := typ_listaetiquetavalor();
v_url     VARCHAR2(200); 
-- 
v_api_path_gnb varchar(1000):= fug_obt_pardinamico( 'V_API_PATH_GNB');
v_path_gnb varchar(1000):= fug_obt_pardinamico( 'V_PATH_GNB');
v_api_key varchar(1000):= fug_obt_pardinamico( 'V_API_KEY');
v_det_error varchar(32760);
--
 v_dat_response VARCHAR2(32760);
 v_ws_respuesta paw_json.JSONStructObj;
 v_ws_res_data paw_json.JSONStructObj;
 v_nombre varchar2(100);
 v_tip_cuenta varchar2(3);
 v_cod_moneda varchar2(3);
 v_nro_cuenta varchar2(100);
 v_error     varchar2(3000);

begin
     --****** Inicio de Proceso Principal *******
     paw_uti.pr_add_value(p_headers, 'Runes-Api-Key', v_api_key);
     v_url := v_api_path_gnb||v_path_gnb||'accountNumber='||p_nro_cuenta||'&documentNumber='||p_nro_documento;
     -- Call the function
     --dbms_output.put_line('entró: '|| to_char(sysdate,'hh24:mi:ss'));
     result := fue_env_http(p_url => v_url,
                 p_metodo => 'GET',
                 p_headers => p_headers);
     --dbms_output.put_line('salió: '||to_char(sysdate,'hh24:mi:ss'));             
     v_error:= result.error;           
     
     if upper(v_error) = 'N' then
         v_ws_respuesta := paw_json.String2JSON(result.respuesta, '"');
         -- se obtiene el tag "data"
         v_dat_response := paw_json.getAttrValue(v_ws_respuesta, 'data');
         -- se convierete el tag "data" a json para leer los atributos
         v_ws_res_data := paw_json.String2JSON(v_dat_response, '"');
         v_nombre := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'shortName')), 1, 100);
         v_tip_cuenta := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'accountType')), 1, 3);
         v_cod_moneda := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'currency')), 1, 3);
         --v_nro_cuenta := substr(trim(paw_json.getAttrValue(v_ws_res_data, 'accountNumber')), 1, 16);
         
         if v_cod_moneda is not null then
             if v_cod_moneda = 'PYG' THEN
                v_cod_moneda:='GS';
             END IF;
             p_cod_moneda:=  v_cod_moneda;      
             
             if upper(v_tip_cuenta)='CC' THEN
                p_cod_modulo:=  '4';              
             else
                p_cod_modulo:=  '3';  
             end if;
             
             p_nom_cliente:= v_nombre; 
             
             p_resultado:=   'S';
         else
           v_det_error :=result.respuesta; 
             p_resultado:=   'N';
             p_cod_moneda:=  null;          
             p_cod_modulo:=  NULL;              
             p_nom_cliente:= NULL; 
             p_cod_error:=   v_det_error;
         
         end if;
           v_ws_res_data.delete;
           v_ws_respuesta.delete;
           p_headers.delete;
     else
         v_det_error :=result.respuesta; 
         p_resultado:=   'N';
         p_cod_moneda:=  null;          
         p_cod_modulo:=  NULL;              
         p_nom_cliente:= NULL; 
         p_cod_error:=   result.codigoError||'-'||result.respuesta;
         p_headers.delete;
     
     end if;
   
end;
/

