import { specialPreviews } from '../data/specialPreviews';

export type RootTabParamList = {
  Home: undefined;
  Preview: undefined;
  Beys: undefined;
  Controls: undefined;
};

export type BeysStackParamList = {
  BeyList: undefined;
  BeyDetail: { beyId: string };
};
