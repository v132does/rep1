create or replace package it.paa_dex is

  /*procedimiento para obtener datos de la persona*/
    procedure pr_obt_val_dat_cliente( p_tip_documento        in number,
                                      p_nro_documento        in varchar2,
                                      p_fec_nacimiento       in date,
                                      p_telefono             in varchar2,
                                      p_tip_operacion        in varchar2, -- D=Deposito / E=Extraccion
                                      p_nro_cta_credito      in out number,
                                      p_cod_persona          out varchar2,
                                      p_nombres              out varchar2,
                                      p_apellidos            out varchar2,
                                      p_cod_error            out number,
                                      p_msj_error            out varchar2);
 
/*procedimiento para validar saldo cliente*/
procedure pr_val_sal_mov_cliente(p_nro_cuenta    in varchar2,
                                                       p_monto         in number, --monto operacion
                                                       p_moneda       in varchar2,----Solo GS
                                                       p_tip_operacion in varchar2,-- D=Deposito / E=Extraccion
                                                       p_mto_total_gs  out number, --Total GS(monto operacion+monto movimiento)
                                                       p_mto_limite    out number,--Mto limite establecido en parametro gral
                                                       p_error         out number,
                                                       p_respuesta     out varchar2);
/*procedimiento para validar saldo extracciones*/
procedure pr_val_sal_extracciones(p_nro_cuenta     in varchar2,
                                  p_monto          in number,
                                  p_moneda       in varchar2,--solo GS
                                  p_respuesta      out varchar2,
                                  p_error          out number,
                                  p_sal_disponible out number);
/*procedimiento para generar pin aleatorio*/
 procedure pr_gen_pin_alea_extracciones(p_cod_persona in varchar2,
                                                            p_nro_celular in varchar2,
                                                            p_error         out number,
                                                            p_respuesta   out varchar2,
                                                            p_pin         out number); 
 /*procedimiento para validar pin aleatorio*/                                                           
procedure pr_val_pin_alea_extracciones(p_cod_persona in varchar2,
                                                              p_pin         in number,
                                                              p_est_actual out varchar2,
                                                              p_error         out number,
                                                              p_respuesta   out varchar2);
 /*procedimiento para generar movimiento deposito*/  
  procedure pr_gen_mov_deposito(p_monto          in number,
                                                     p_nro_cuenta     in varchar2,--cuenta cliente credito
                                                     p_cod_moneda      in varchar2,--solo GS
                                                     p_mov_id         out varchar2,--Movimiento_id
                                                     p_fecha          out varchar2,--Fecha
                                                     p_cta_nro         out varchar2,--Cta numero
                                                     p_titular         out varchar2,--Nombre completo Titular Cta
                                                     p_moneda          out varchar2,--Moneda
                                                     p_tot_dep         out varchar2,--Total depositado
                                                     p_cod_error      out number,
                                                     p_msj_error      out varchar2); 
 /*procedimiento para generar movimiento extraccion*/   
 procedure pr_gen_mov_extraccion( p_nro_cuenta  in varchar2,--cuenta cliente
                                                      p_moneda     in varchar2,--GS
                                                      p_monto       in number,--monto extraccion
                                                      p_cod_persona in varchar2,
                                                      p_mov_id         out varchar2,--Movimiento_id
                                                      p_fecha          out varchar2,--Fecha
                                                      p_cta_nro         out varchar2,--Cta numero
                                                      p_moneda_cta          out varchar2,--Moneda
                                                      p_total_ext         out number,--Total extraccion
                                                      p_nom_per         out varchar2,
                                                      p_tip_doc_per         out varchar2,
                                                      p_nro_doc_per         out varchar2,
                                                      p_error       out number,
                                                      p_respuesta   out varchar2);  
 /*procedimiento para reversar movimiento deposito-extraccion*/   
 procedure pr_gen_rev_operacion(p_mov_id in varchar2,
                                                     p_cod_error  out number,
                                                     p_msj_error  out varchar2);
 function fu_es_conjunta(p_nro_cuenta in varchar2) return varchar2;                                                     
   /*procedimiento para actualizar estado pin aleatorio*/
 procedure pr_act_estado_pin(p_cod_persona in varchar2,
                              p_pin         in number,
                              p_est_actual  out varchar2,
                              p_error       out number,
                              p_respuesta   out varchar2);  
                              
 /*funcion que retorna usuario para evitar error de pk en ge_movimientos*/                            
  function fu_obt_mov_usuario(p_tip_usuario in ba_cod_referencias.abreviatura%type) return varchar2;
  /*funcion que retorna hora para evitar error de pk en ge_movimientos*/                                                                                                                                                                                  
  function fu_obt_hora(p_cod_usuario varchar2) return varchar2;
  /*procedimiento para validar saldo cliente wepa*/
procedure pr_val_sal_mov_cliente_wp(p_nro_cuenta    in varchar2,
                                                       p_monto         in number, --monto operacion
                                                       p_moneda       in varchar2,----Solo GS
                                                       p_tip_operacion in varchar2,-- D=Deposito / E=Extraccion
                                                       p_mto_total_gs  out number, --Total GS(monto operacion+monto movimiento)
                                                       p_mto_limite    out number,--Mto limite establecido en parametro gral
                                                       p_error         out number,
                                                       p_respuesta     out varchar2);
end paa_dex;
/
