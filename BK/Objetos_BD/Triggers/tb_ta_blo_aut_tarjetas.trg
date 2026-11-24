CREATE OR REPLACE TRIGGER IT.tb_ta_blo_aut_tarjetas
  before insert on ta_blo_aut_tarjetas  
  for each row
DECLARE
   /*
   Campo   Descripción         Tipo/Longitud  Valores
   ==================================================
   TrjNro  Nro. de tarjeta     Character(19)  In    
   AccCod  Cód. de acción      Character(4)   In   Ver Códigos de Acción
   TBId    Tipo de bloqueo     Character(1)   In   A: ADMINISTRATIVO, U: USUARIO
   OpeTip  Tipo de operación   Character(3)   In   Ver Tipos de Operaciones
   AmbBlo  Ambiente de bloqueo Character(1)   In   L: Local, I: Internacional
   ForBlo  Forma de bloqueo    Character(1)   In   T: Temporal, D: Definitivo
   MBId    Motivo de Bloqueo   Numeric(2.0)   In   Ver Motivos de Bloqueos
   UsuUpd  Usuario del pedido  Character(10)  In    
   MesPur  Meses de purga      Numeric(3.0)   In   Cantidad de meses que se desea para la purga
                               0 (cero) = se buscan valores Standard ya sean genéricos o por entidad
                               999      =  Hasta la cantidad máxima permitida por la  marca
                               998      = Hasta Vencimiento del plástico
   ResCod    Respuesta Character(2)  Out 00 = Transacción Aprobada, 06 = Transacción Rechazada
   ResExt    Respuesta extendida  Character(4) Out   
   */
BEGIN
   :new.dat_bloqueo := :new.nro_tarjeta   || ' ' ||
                       :new.cod_accion    || ' ' ||
                       :new.tip_bloqueo   || ' ' ||
                       :new.tip_operacion || ' ' ||
                       :new.amb_bloqueo   || ' ' ||
                       :new.for_bloqueo   || ' ' ||
                       :new.cod_motivo    || ' ' ||
                       nvl(:new.usu_actualizacion,substr(user,1,10)) || ' ' ||
                       :new.mes_purga;

END ta_ta_blo_aut_tarjetas;
/

